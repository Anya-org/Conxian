const fs = require('fs');
const path = require('path');

function rebuild_clarinet_toml(project_dir) {
    const contracts_dir = path.join(project_dir, 'contracts');

    // 1. Find all .clar files
    const clar_files = [];
    function walk(dir) {
        fs.readdirSync(dir).forEach(f => {
            const fp = path.join(dir, f);
            if (fs.statSync(fp).isDirectory()) walk(fp);
            else if (f.endsWith('.clar')) clar_files.push(fp);
        });
    }
    walk(contracts_dir);

    // 2. Extract dependencies via AST scan (contract-call?, impl-trait, use-trait)
    const dependencies = {};
    for (const filePath of clar_files) {
        const content = fs.readFileSync(filePath, 'utf8');
        const name = path.basename(filePath).replace('.clar', '');
        const deps = new Set();

        let m;
        const callRe = /contract-call\?\s+\.([a-zA-Z0-9_-]+)/g;
        while ((m = callRe.exec(content)) !== null) deps.add(m[1]);

        const implRe = /impl-trait\s+\.([a-zA-Z0-9_-]+)/g;
        while ((m = implRe.exec(content)) !== null) deps.add(m[1]);

        const useRe = /use-trait\s+[a-zA-Z0-9_-]+\s+\.([a-zA-Z0-9_-]+)/g;
        while ((m = useRe.exec(content)) !== null) deps.add(m[1]);

        deps.delete(name);

        const rel = path.relative(project_dir, filePath).replace(/\\/g, '/');
        dependencies[name] = { path: rel, deps: Array.from(deps) };
    }

    // 3. Topological sort for deployment order
    const sorted = [];
    const visited = new Set();
    function visit(n) {
        if (visited.has(n)) return;
        visited.add(n);
        if (dependencies[n]) dependencies[n].deps.forEach(d => visit(d));
        sorted.push(n);
    }
    Object.keys(dependencies).forEach(k => visit(k));

    // 4. Build TOML — exact official SDK format
    //    ref: https://docs.hiro.so/tools/clarinet/project-structure
    const lines = [
        '[project]',
        'name = "Conxian"',
        'description = ""',
        'authors = []',
        'telemetry = false',
        'requirements = []',
        'clarinet_version = "3.12.0"',
        '',
        '[accounts]',
        'deployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"',
        '',
        '[simnet]',
        'mnemonic = "cute bird surprise boring old news cake design aisle helmet choose tree"',
        '',
        '[repl.analysis]',
        'passes = ["check_checker"]',
        '',
        '[repl.analysis.check_checker]',
        'strict = false',
        'trusted_sender = false',
        'trusted_caller = false',
        'callee_filter = false',
        ''
    ];

    for (const name of sorted) {
        if (!dependencies[name]) continue;
        const d = dependencies[name];
        lines.push(`[contracts.${name}]`);
        lines.push(`path = "${d.path}"`);
        lines.push(`clarity_version = 4`);
        lines.push(`epoch = "3.3"`);
        if (d.deps.length > 0) {
            lines.push(`depends_on = [${d.deps.map(dep => `"${dep}"`).join(', ')}]`);
        }
        lines.push('');
    }

    fs.writeFileSync(path.join(project_dir, 'Clarinet.toml'), lines.join('\n'));
    console.log(`[OK] Rebuilt Clarinet.toml with ${sorted.length} contracts.`);
}

rebuild_clarinet_toml(__dirname);
