import { antfu } from '@antfu/eslint-config';
import { createBaseConfigs } from '@kikiutils/eslint-config/base';
import { createVsCodeJsonConfigs } from '@kikiutils/eslint-config/json';

export default antfu(
    {
        ignores: [
            '**/*',
            '!.vscode/**',
            '!*.yaml',
            '!eslint.config.mjs',
            '!package.json',
        ],
        typescript: true,
    },
    createBaseConfigs(),
    createVsCodeJsonConfigs(),
);
