module.exports = {
  root: true,
  extends: '@react-native',
  parserOptions: {
    requireConfigFile: false,
  },
  rules: {
    'react/no-unstable-nested-components': ['warn', { allowAsProps: true }],
  },
};
