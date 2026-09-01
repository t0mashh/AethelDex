const fs = require('fs');
const luaparse = require('luaparse');

const code = fs.readFileSync('AethelDex.lua', 'utf8');
const lines = code.split(/\r?\n/);

console.log("Total lines:", lines.length);

// Test incrementally to find the offending line
let accum = "";
for (let i = 0; i < lines.length; i++) {
    accum += lines[i] + "\n";
    try {
        luaparse.parse(accum);
    } catch (e) {
        // Only report if it's not premature EOF
        if (!e.message.includes("<eof>") && !e.message.includes("expected")) {
            console.log("Error at line", i + 1, ":", e.message, "->", lines[i]);
            break;
        }
    }
}
