import { antfu } from '@antfu/eslint-config';
import { createBaseConfigs } from '@kikiutils/eslint-config/base';

export default antfu(
    {
        ignores: [
            '**/*',
            '!.vscode/**',
            '!*.yaml',
            '!eslint.config.mjs',
            '!package.json',
        ],
    },
    createBaseConfigs(),
);
