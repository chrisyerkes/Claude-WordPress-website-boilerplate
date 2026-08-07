import globals from 'globals';

export default [
	{
		files: [ 'themes/starter/src/js/**/*.js', 'plugins/*/src/js/**/*.js' ],
		languageOptions: {
			ecmaVersion: 2022,
			sourceType: 'module',
			globals: {
				...globals.browser,
				wp: 'readonly',
				acf: 'readonly', // ACF JS API (when using ACF)
				jQuery: 'off', // Disallow jQuery
			},
		},
		rules: {
			'no-var': 'error',
			'prefer-const': 'warn',
			'no-unused-vars': [ 'warn', { argsIgnorePattern: '^_' } ],
			'no-console': [ 'warn', { allow: [ 'warn', 'error' ] } ],
			eqeqeq: [ 'error', 'always' ],
			curly: [ 'error', 'all' ],
		},
	},
	{
		files: [ 'build/**/*.mjs' ],
		languageOptions: {
			ecmaVersion: 2022,
			sourceType: 'module',
			globals: {
				...globals.node,
			},
		},
	},
	{
		ignores: [
			'themes/starter/assets/js/**',
			'plugins/*/assets/js/**',
			'node_modules/**',
		],
	},
];
