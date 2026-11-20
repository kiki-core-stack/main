#!/usr/bin/env node

// Never prints values. render includes the build args, as a dev server builds as it runs.

import { execFileSync } from 'node:child_process';
import {
    chmodSync,
    existsSync,
    readFileSync,
    writeFileSync,
} from 'node:fs';
import {
    basename,
    join,
    relative,
    resolve,
    sep,
} from 'node:path';
import { parseEnv } from 'node:util';

// Constants/Variables
const mainDir = resolve(import.meta.dirname, '..');
const reposDir = join(mainDir, 'repos');

// Compose runs with only these variables, so the shell's own variables cannot override the profile.
const passedEnvNames = [
    'DOCKER_CONFIG',
    'DOCKER_CONTEXT',
    'DOCKER_HOST',
    'HOME',
    'PATH',
    'XDG_RUNTIME_DIR',
];

// Functions
function fail(message) {
    console.error(`ERROR: ${message}`);
    process.exit(1);
}

function runComposeConfig(profileName, profilePath, args) {
    const composeFiles = ['docker-compose.yaml', ...profileName === 'development' ? ['dev.compose.yaml'] : []];
    try {
        return execFileSync(
            'docker',
            [
                'compose',
                ...composeFiles.flatMap((file) => ['-f', join(mainDir, file)]),
                '--env-file',
                profilePath,
                'config',
                ...args,
            ],
            {
                cwd: mainDir,
                encoding: 'utf8',
                env: Object.fromEntries(passedEnvNames.filter((name) => process.env[name]).map((name) => [name, process.env[name]])),
                stdio: [
                    'ignore',
                    'pipe',
                    'pipe',
                ],
            },
        );
    } catch (error) {
        fail(`docker compose config failed:\n${error.stderr?.trim() || error.message}`);
    }
}

function checkProfile(profileName) {
    const profileDir = join(mainDir, 'profiles', profileName);
    const profilePath = join(profileDir, '.env');
    const examplePath = join(profileDir, '.env.example');
    if (!existsSync(examplePath)) fail(`Unknown profile: ${profileName} (${relative(mainDir, examplePath)} not found)`);
    if (!existsSync(profilePath)) fail(`${relative(mainDir, profilePath)} not found; copy it from .env.example`);

    const profileKeys = new Set(Object.keys(parseEnv(readFileSync(profilePath, 'utf8'))));
    const exampleKeys = Object.keys(parseEnv(readFileSync(examplePath, 'utf8')));
    const missingKeys = exampleKeys.filter((key) => !profileKeys.has(key));
    if (missingKeys.length) fail(`${relative(mainDir, profilePath)} is missing: ${missingKeys.join(', ')}`);
    const extraKeys = [...profileKeys].filter((key) => !exampleKeys.includes(key));
    if (extraKeys.length) console.warn(`WARN: Not in .env.example (unused?): ${extraKeys.join(', ')}`);

    const config = JSON.parse(runComposeConfig(profileName, profilePath, ['--format', 'json']));

    const resolvedEnv = new Map();
    for (const line of runComposeConfig(profileName, profilePath, ['--environment']).split('\n')) {
        const separatorIndex = line.indexOf('=');
        if (separatorIndex > 0) resolvedEnv.set(line.slice(0, separatorIndex), line.slice(separatorIndex + 1));
    }

    // Compose accepts a secret whose variable is empty, so it is checked here.
    const emptySecretEnvNames = Object.values(config.secrets ?? {})
        .map((secret) => secret.environment)
        .filter((name) => name && !resolvedEnv.get(name));

    if (emptySecretEnvNames.length) fail(`Secrets without a value: ${[...new Set(emptySecretEnvNames)].join(', ')}`);
    console.log(`Profile ${profileName} OK`);
    return {
        config,
        resolvedEnv,
    };
}

function render() {
    const {
        config,
        resolvedEnv,
    } = checkProfile('development');

    for (const [serviceName, service] of Object.entries(config.services)) {
        const context = service.build?.context;
        if (!context || !resolve(context).startsWith(`${reposDir}${sep}`)) continue;
        if (!existsSync(context)) {
            console.warn(`WARN: Skipped ${serviceName}: ${relative(mainDir, context)} not found`);
            continue;
        }

        const env = new Map(
            [
                ...Object.entries(service.build.args ?? {}),
                ...Object.entries(service.environment ?? {}),
            ].filter(([, value]) => value !== null),
        );

        for (const { source, target } of service.secrets ?? []) {
            env.set(basename(target ?? source), resolvedEnv.get(config.secrets[source].environment));
        }

        const lines = [...env.keys()].sort().map((key) => {
            const value = String(env.get(key));
            // Single quotes keep the value literal, newlines included, for every loader (Bun, dotenv, dotenvy, shell `.`).
            if (value.includes("'")) fail(`${serviceName}: the value of ${key} contains a single quote`);
            return `${key}='${value}'`;
        });

        const envFilePath = join(resolve(context), '.env.development.local');
        writeFileSync(
            envFilePath,
            `# Generated by main/scripts/profile.mjs from profiles/development/.env; edit the profile instead.\n${lines.join('\n')}\n`,
            { mode: 0o600 },
        );

        chmodSync(envFilePath, 0o600);
        console.log(`Rendered ${relative(mainDir, envFilePath)} (${lines.length} variables)`);
    }
}

// Run
const [command, profileName] = process.argv.slice(2);
if (command === 'check' && profileName) checkProfile(profileName);
else if (command === 'render' && !profileName) render();
else fail('Usage: profile.mjs check <name> | profile.mjs render');
