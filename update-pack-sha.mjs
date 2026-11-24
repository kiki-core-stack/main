#!/usr/bin/env node

import { execFile } from 'node:child_process';
import { existsSync } from 'node:fs';
import {
    glob,
    readFile,
    writeFile,
} from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';

const envFilePath = join(import.meta.dirname, 'profiles/development/.env');
if (!existsSync(envFilePath)) throw new Error('profiles/development/.env not found; copy it from .env.example');
process.loadEnvFile(envFilePath);
const packGitRef = process.env.PACK_GIT_REF;
if (!packGitRef) throw new Error('PACK_GIT_REF must be set in profiles/development/.env');

const packGitRevisions = new Map();
const run = promisify(execFile);

async function resolvePackGitRevision(remoteUrl) {
    if (/^[\da-f]{40}$/.test(packGitRef)) return packGitRef;

    const { stdout } = await run(
        'git',
        [
            'ls-remote',
            remoteUrl,
            packGitRef,
        ],
    );

    const entries = stdout.trim().split('\n').filter(Boolean).map((line) => line.split(/\s+/));
    // Annotated tags also list the tag object; pin the commit it points to (the peeled `^{}` entry).
    const peeledEntries = entries.filter(([, ref]) => ref.endsWith('^{}'));
    const revisions = new Set((peeledEntries.length ? peeledEntries : entries).map(([revision]) => revision));
    if (revisions.size !== 1) throw new Error(`${remoteUrl}: ${packGitRef} matches ${revisions.size} revisions`);
    return [...revisions][0];
}

async function getPackGitRevision(remoteUrl) {
    if (!packGitRevisions.has(remoteUrl)) {
        const packGitRevision = await resolvePackGitRevision(remoteUrl);
        packGitRevisions.set(remoteUrl, packGitRevision);
        process.stdout.write(`${remoteUrl}: ${packGitRevision}\n`);
    }

    return packGitRevisions.get(remoteUrl);
}

for await (const filePath of glob('repos/*/package.json', { cwd: import.meta.dirname })) {
    const resolvedFilePath = join(import.meta.dirname, filePath);
    const originalFileContent = await readFile(resolvedFilePath, 'utf8');
    const packageManifest = JSON.parse(originalFileContent);
    const dependency = packageManifest.dependencies?.['@kcs-project/pack'];

    if (!dependency) continue;

    const sourceUrl = dependency.split('#')[0];
    const remoteUrl = sourceUrl.replace(/^git\+/, '').replace(/^github:/, 'https://github.com/');
    const updatedDependency = `${sourceUrl}#${await getPackGitRevision(remoteUrl)}`;

    if (updatedDependency === dependency) continue;

    packageManifest.dependencies['@kcs-project/pack'] = updatedDependency;
    await writeFile(resolvedFilePath, `${JSON.stringify(packageManifest, null, 2)}\n`);
    process.stdout.write(`Updated ${filePath}\n`);
}

for await (const filePath of glob('repos/*/Cargo.toml', { cwd: import.meta.dirname })) {
    const resolvedFilePath = join(import.meta.dirname, filePath);
    const originalFileContent = await readFile(resolvedFilePath, 'utf8');
    const dependencyLine = originalFileContent.match(/^kcs-project-pack\s*=.*$/m)?.[0];
    const remoteUrl = dependencyLine?.match(/\bgit\s*=\s*"([^"]+)"/)?.[1];

    if (!remoteUrl || !/\brev\s*=\s*"[^"]*"/.test(dependencyLine)) continue;

    const updatedDependencyLine = dependencyLine.replace(
        /\brev\s*=\s*"[^"]*"/,
        `rev = "${await getPackGitRevision(remoteUrl)}"`,
    );

    if (updatedDependencyLine === dependencyLine) continue;

    await writeFile(resolvedFilePath, originalFileContent.replace(dependencyLine, () => updatedDependencyLine));
    process.stdout.write(`Updated ${filePath}\n`);
}
