#!/usr/bin/env node

import { execFile } from 'node:child_process';
import {
    glob,
    readFile,
    writeFile,
} from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';

process.loadEnvFile(join(import.meta.dirname, '.env.development.local'));
const packGitRef = process.env.PACK_GIT_REF;
if (!packGitRef) throw new Error('PACK_GIT_REF must be set in .env.development.local');

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

for await (const filePath of glob('repos/*/package.json', { cwd: import.meta.dirname })) {
    const resolvedFilePath = join(import.meta.dirname, filePath);
    const originalFileContent = await readFile(resolvedFilePath, 'utf8');
    const packageManifest = JSON.parse(originalFileContent);
    const dependency = packageManifest.dependencies?.['@kcs-project/pack'];

    if (!dependency) continue;

    const sourceUrl = dependency.split('#')[0];
    const remoteUrl = sourceUrl.replace(/^git\+/, '').replace(/^github:/, 'https://github.com/');

    if (!packGitRevisions.has(remoteUrl)) {
        const packGitRevision = await resolvePackGitRevision(remoteUrl);
        packGitRevisions.set(remoteUrl, packGitRevision);
        process.stdout.write(`${remoteUrl}: ${packGitRevision}\n`);
    }

    const updatedDependency = `${sourceUrl}#${packGitRevisions.get(remoteUrl)}`;

    if (updatedDependency === dependency) continue;

    packageManifest.dependencies['@kcs-project/pack'] = updatedDependency;
    await writeFile(resolvedFilePath, `${JSON.stringify(packageManifest, null, 2)}\n`);
    process.stdout.write(`Updated ${filePath}\n`);
}
