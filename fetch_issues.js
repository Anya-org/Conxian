const https = require('https');

const options = {
  hostname: 'api.github.com',
  path: '/repos/Conxian/conxius-platform/issues',
  headers: {
    'User-Agent': 'Node.js Script'
  }
};

https.get(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const issues = JSON.parse(data);
      console.log(issues.map(i => `#${i.number}: ${i.title}`).join('\n'));
    } catch(e) {
      console.error('Parse error:', e, data);
    }
  });
}).on('error', err => console.error(err));
