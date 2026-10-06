#!/usr/bin/env node

import { execFile } from 'node:child_process';
import {
    glob,
    readFile,
    writeFile,
} from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';

const packGitRevisions = new Map();
const run = promisify(execFile);

for await (const filePath of glob('repos/*/package.json', { cwd: import.meta.dirname })) {
    const resolvedFilePath = join(import.meta.dirname, filePath);
    const originalFileContent = await readFile(resolvedFilePath, 'utf8');
    const packageManifest = JSON.parse(originalFileContent);
    const dependency = packageManifest.dependencies?.['@kcs-project/pack'];

    if (!dependency) continue;

    const sourceUrl = dependency.split('#')[0];
    const remoteUrl = sourceUrl.replace(/^git\+/, '').replace(/^github:/, 'https://github.com/');

    if (!packGitRevisions.has(remoteUrl)) {
        const { stdout } = await run(
            'git',
            [
                'ls-remote',
                remoteUrl,
                'HEAD',
            ],
        );

        const packGitRevision = stdout.trim().split(/\s+/)[0];
        packGitRevisions.set(remoteUrl, packGitRevision);
        process.stdout.write(`${remoteUrl}: ${packGitRevision}\n`);
    }

    const updatedDependency = `${sourceUrl}#${packGitRevisions.get(remoteUrl)}`;

    if (updatedDependency === dependency) continue;

    packageManifest.dependencies['@kcs-project/pack'] = updatedDependency;
    await writeFile(resolvedFilePath, `${JSON.stringify(packageManifest, null, 2)}\n`);
    process.stdout.write(`Updated ${filePath}\n`);
}
