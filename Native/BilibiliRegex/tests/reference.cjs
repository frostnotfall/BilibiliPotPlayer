// Reference semantics verified against the web player's core.9b2f4c3c.js.
// Run under Node/V8, keeping it independent of the DLL under test.
const fs = require('node:fs');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
function compileRule(rule) {
  const parts = /^\/(.+)\/([img]{0,3})$/.exec(rule);
  try { return new RegExp(parts[1], parts[2]); }
  catch { return new RegExp(rule); }
}
const results = input.map(({mode, pattern, flags, text}) => {
  try {
    const regex = mode === 'rule' ? compileRule(pattern) : new RegExp(pattern, flags);
    return regex.test(text) ? 1 : 0;
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    return -2;
  }
});
process.stdout.write(JSON.stringify({node:process.version, v8:process.versions.v8, results}));
