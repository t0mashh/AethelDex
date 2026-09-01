const fs = require('fs');
const path = require('path');

function cleanFile(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');

    // Clean function headers: function foo(a: type, b: type): retType -> function foo(a, b)
    // Handle nested parens in types like (fn: (...) -> ())
    content = content.replace(/function\s+([a-zA-Z0-9_:\.]+)\s*(?:<[^>]+>)?\s*\(([\s\S]*?)\)(?:\s*:\s*[^\r\n\{]+)?/g, (match, funcName, rawParams) => {
        // Skip if multiline body was somehow matched
        if (rawParams.includes('local ') || rawParams.includes('return ') || rawParams.includes('\n\n')) {
            return match;
        }
        // Clean each parameter
        const params = rawParams.split(',').map(p => {
            let s = p.trim();
            const colon = s.indexOf(':');
            if (colon !== -1) {
                s = s.substring(0, colon).trim();
            }
            return s;
        }).filter(p => p.length > 0).join(', ');

        return `function ${funcName}(${params})`;
    });

    // Also clean local function foo(a: type): retType
    content = content.replace(/local\s+function\s+([a-zA-Z0-9_]+)\s*(?:<[^>]+>)?\s*\(([\s\S]*?)\)(?:\s*:\s*[^\r\n\{]+)?/g, (match, funcName, rawParams) => {
        if (rawParams.includes('local ') || rawParams.includes('return ') || rawParams.includes('\n\n')) {
            return match;
        }
        const params = rawParams.split(',').map(p => {
            let s = p.trim();
            const colon = s.indexOf(':');
            if (colon !== -1) {
                s = s.substring(0, colon).trim();
            }
            return s;
        }).filter(p => p.length > 0).join(', ');

        return `local function ${funcName}(${params})`;
    });

    // Remove (self :: any) :: type
    content = content.replace(/\(self\s*::\s*any\)\s*::\s*[A-Za-z0-9_\.<\?, ]+/g, 'self');
    content = content.replace(/::\s*[A-Za-z0-9_\.<\?, ]+/g, '');

    // Remove local variable types: local x: Type = ... -> local x = ...
    content = content.replace(/local\s+([a-zA-Z0-9_]+)\s*:\s*[A-Za-z0-9_\.<\?, \[\]\{\}]+\s*=/g, 'local $1 =');
    // Remove standalone local variable declarations: local x: Type -> local x
    content = content.replace(/local\s+([a-zA-Z0-9_]+)\s*:\s*[A-Za-z0-9_\.<\?, \[\]\{\}]+/g, 'local $1');

    fs.writeFileSync(filePath, content, 'utf8');
}

function walk(dir) {
    fs.readdirSync(dir).forEach(f => {
        const p = path.join(dir, f);
        if (fs.statSync(p).isDirectory()) {
            walk(p);
        } else if (p.endsWith('.luau')) {
            cleanFile(p);
            console.log('Cleaned:', p);
        }
    });
}

walk(path.join(__dirname, '..', 'src'));
console.log('Finished cleaning function signatures in src/');
