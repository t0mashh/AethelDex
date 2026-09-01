// [strip_types.js]
// Strips Luau-only annotations from bundle to produce 100% universal Lua 5.1 / Luau code

const fs = require('fs');
const path = require('path');

const bundlePath = path.join(__dirname, '..', 'AethelDex.luau');
let code = fs.readFileSync(bundlePath, 'utf8');

// 1. Strip UTF-8 BOM if present
code = code.replace(/^\uFEFF/, '');

// 2. Remove --!strict or other compiler directives
code = code.replace(/^--!(?:strict|nonstrict).*\r?\n/gm, '');

// 3. Brace-aware removal of all `type ... = { ... }` blocks (including nested braces)
function removeTypeDefinitions(src) {
    const lines = src.split(/\r?\n/);
    const result = [];
    let inType = false;
    let braceDepth = 0;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trim();

        if (!inType) {
            if (/^(?:export\s+)?type\s+[A-Za-z0-9_]+/.test(trimmed)) {
                inType = true;
                const openCount = (line.match(/\{/g) || []).length;
                const closeCount = (line.match(/\}/g) || []).length;
                braceDepth = openCount - closeCount;
                if (braceDepth <= 0 && (!line.includes('{') || openCount === closeCount)) {
                    inType = false;
                }
                continue;
            }
            result.push(line);
        } else {
            const openCount = (line.match(/\{/g) || []).length;
            const closeCount = (line.match(/\}/g) || []).length;
            braceDepth += openCount - closeCount;
            if (braceDepth <= 0) {
                inType = false;
            }
        }
    }
    return result.join('\n');
}

code = removeTypeDefinitions(code);

// 4. Replace compound assignments (index += 1 -> index = index + 1)
code = code.replace(/([a-zA-Z0-9_\.]+)\s*\+=\s*([^;\r\n]+)/g, '$1 = $1 + $2');
code = code.replace(/([a-zA-Z0-9_\.]+)\s*-=\s*([^;\r\n]+)/g, '$1 = $1 - $2');

// 5. Remove :: casts
code = code.replace(/::\s*\{[^}]*\}/g, '');
code = code.replace(/::\s*[A-Za-z0-9_\.<\?, \(\)]+/g, '');

// 6. Clean empty parens or double self casts
code = code.replace(/\(\s*self\s*\)/g, 'self');

// Write clean files
fs.writeFileSync(path.join(__dirname, '..', 'AethelDex.lua'), code, 'utf8');
fs.writeFileSync(bundlePath, code, 'utf8');

console.log('Successfully produced universal bundle with brace-aware type stripper!');
