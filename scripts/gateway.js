#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const taskId = process.argv[2];
const outputFilePath = process.argv[3];

// 读取安全规则
const rulesFile = path.join(__dirname, '../security-rules.json');
let rules;
try {
  rules = JSON.parse(fs.readFileSync(rulesFile, 'utf8'));
} catch (e) {
  rules = {
    forbidden_patterns: [
      { "pattern": "password\\s*=\\s*['\"][^'\"]+['\"]", "message": "发现硬编码密码", "severity": "critical" },
      { "pattern": "api_key\\s*=\\s*['\"][^'\"]+['\"]", "message": "发现硬编码 API 密钥", "severity": "critical" }
    ],
    dangerous_imports: ["child_process", "fs/promises", "vm"]
  };
}

// 读取角色输出
let output;
try {
  output = JSON.parse(fs.readFileSync(outputFilePath, 'utf8'));
} catch (e) {
  output = { artifacts: [] };
}
const artifacts = output.artifacts || [];

const violations = [];

// 检查每个产出文件
for (const artifact of artifacts) {
  const fullPath = path.join(process.cwd(), artifact);
  if (!fs.existsSync(fullPath)) continue;
  
  const stats = fs.statSync(fullPath);
  const sizeKB = stats.size / 1024;
  if (sizeKB > (rules.max_file_size_kb || 100)) {
    violations.push({
      rule: "max_file_size_kb",
      file: artifact,
      line: null,
      message: `文件大小 ${sizeKB.toFixed(2)} KB 超过限制`
    });
  }
  
  const content = fs.readFileSync(fullPath, 'utf8');
  const lines = content.split('\n');
  
  // 检查禁止模式
  for (const patternDef of rules.forbidden_patterns || []) {
    const regex = new RegExp(patternDef.pattern, 'gi');
    for (let i = 0; i < lines.length; i++) {
      if (regex.test(lines[i])) {
        violations.push({
          rule: patternDef.pattern,
          file: artifact,
          line: i + 1,
          message: patternDef.message
        });
      }
    }
  }
  
  // 检查危险导入
  for (const dangerous of rules.dangerous_imports || []) {
    const importRegex = new RegExp(`require\\(['"]${dangerous}['"]\\)|from ['"]${dangerous}['"]`, 'gi');
    for (let i = 0; i < lines.length; i++) {
      if (importRegex.test(lines[i])) {
        violations.push({
          rule: "dangerous_import",
          file: artifact,
          line: i + 1,
          message: `使用了危险模块 ${dangerous}`
        });
      }
    }
  }
}

const report = {
  taskId: taskId,
  status: violations.length === 0 ? 'approved' : 'rejected',
  violations: violations
};

console.log(JSON.stringify(report));
