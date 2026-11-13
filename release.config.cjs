const parserOpts = { noteKeywords: ['BREAKING CHANGE', 'BREAKING-CHANGE'] };
module.exports = {
  branches: ['main'], tagFormat: 'v${version}',
  plugins: [
    ['@semantic-release/commit-analyzer', { preset: 'conventionalcommits', parserOpts }],
    ['@semantic-release/release-notes-generator', { preset: 'conventionalcommits', parserOpts }],
    ['@semantic-release/exec', { prepareCmd: 'node scripts/prepare.mjs ${nextRelease.version}' }],
    ['@semantic-release/github', {
      assets: [
        {path: 'dist/Pink-*.zip'}, {path: 'dist/Pink-*.dmg'},
        {path: 'dist/SHA256SUMS'}, {path: 'dist/build-info.json'}
      ], successComment: false, failComment: false, releasedLabels: false
    }]
  ]
};
