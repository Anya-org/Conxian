const https = require('https');

const options = (issue) => ({
  hostname: 'api.github.com',
  path: `/repos/Conxian/conxius-platform/issues/${issue}`,
  headers: {
    'User-Agent': 'Node.js Script'
  }
});

const fetchIssue = (issue) => {
  https.get(options(issue), (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log(`\n\n--- ISSUE ${issue} ---\n`);
      console.log(JSON.parse(data).body);
    });
  });
};

fetchIssue(568);
fetchIssue(431);
