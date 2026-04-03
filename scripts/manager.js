#!/usr/bin/env node
const os = require("os");

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const readline = require('readline');

// 配置路径
const BASE_DIR = path.join(__dirname, '..');
const TEAM_DIR = path.join(process.cwd(), '.team');
const ROLES_DIR = path.join(BASE_DIR, 'roles');
const WORKTREES_DIR = path.join(TEAM_DIR, 'worktrees');
const OUTPUTS_DIR = path.join(TEAM_DIR, 'outputs');
const REPORTS_DIR = path.join(TEAM_DIR, 'reports');
const TASKS_FILE = path.join(TEAM_DIR, 'tasks.json');
const DESIGN_FILE = path.join(TEAM_DIR, 'design.md');

// 检测 openclaw 目录
function detectOpenclaw() {
  if (fs.existsSync('./openclaw')) {
    return path.join(process.cwd(), 'openclaw', 'skills');
  } else if (fs.existsSync(path.join(os.homedir(), 'openclaw'))) {
    return path.join(os.homedir(), 'openclaw', 'skills');
  } else if (fs.existsSync('/opt/openclaw')) {
    return path.join('/opt/openclaw', 'skills');
  }
  return path.join(os.homedir(), '.openclaw', 'skills');
}
const OPENCLAW_SKILLS = detectOpenclaw();

// 确保目录存在
[TEAM_DIR, WORKTREES_DIR, OUTPUTS_DIR, REPORTS_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// 工具函数：读取角色，优先加载角色自己的技能
function loadRoles() {
  const roles = [];
  if (!fs.existsSync(ROLES_DIR)) return roles;
  const roleDirs = fs.readdirSync(ROLES_DIR);
  
  for (const roleDir of roleDirs) {
    const rolePath = path.join(ROLES_DIR, roleDir);
    const roleCharPath = path.join(rolePath, 'Character.md');
    if (fs.existsSync(roleCharPath)) {
      // 检查角色自己的技能库
      const roleSkillsPath = path.join(rolePath, 'skills');
      let availableSkills = [];
      if (fs.existsSync(roleSkillsPath)) {
        availableSkills = fs.readdirSync(roleSkillsPath);
      }
      
      roles.push({
        name: roleDir,
        display_name: roleDir,
        char_path: roleCharPath,
        local_skills: availableSkills,
        is_builtin: roleDir === 'manager' || roleDir === 'security_gateway'
      });
    }
  }
  return roles;
}

// 查找技能，优先角色本地，然后全局
function findSkill(role, skillName) {
  // 先检查角色自己的技能
  if (role.local_skills.includes(skillName)) {
    return path.join(ROLES_DIR, role.name, 'skills', skillName);
  }
  // 再检查主技能的本地skills
  const mainSkills = path.join(BASE_DIR, 'skills', skillName);
  if (fs.existsSync(mainSkills)) {
    return mainSkills;
  }
  // 最后检查openclaw的全局skills
  if (fs.existsSync(path.join(OPENCLAW_SKILLS, skillName))) {
    return path.join(OPENCLAW_SKILLS, skillName);
  }
  return null;
}

// 根据任务描述匹配最佳角色技能
function matchRole(taskDescription, roles) {
  let bestRole = null;
  let bestScore = 0;
  
  const roleKeywords = {
    developer: ['实现', '代码', '函数', '接口', '测试', '开发', '编码', 'bug', '修复'],
    clerk: ['文档', 'README', '注释', '配置', '整理', 'excel', '表格', '行政', '归档'],
    security_gateway: ['安全', '审查', '检查', '审计', '扫描'],
    manager: ['管理', '协调', '规划', '分配']
  };
  
  for (const role of roles) {
    const keywords = roleKeywords[role.name] || [];
    const matchCount = keywords.filter(kw => 
      taskDescription.toLowerCase().includes(kw.toLowerCase())
    ).length;
    
    if (matchCount > bestScore) {
      bestScore = matchCount;
      bestRole = role;
    }
  }
  return bestRole || roles.find(r => r.name === 'manager');
}

// 创建隔离 worktree
function createWorktree(roleName, taskId) {
  const worktreePath = path.join(WORKTREES_DIR, `${roleName}-${taskId}`);
  if (fs.existsSync(worktreePath)) {
    execSync(`rm -rf ${worktreePath}`);
  }
  const currentBranch = execSync('git rev-parse --abbrev-ref HEAD').toString().trim();
  const newBranch = `team/${roleName}-${taskId}`;
  execSync(`git worktree add -b ${newBranch} ${worktreePath} ${currentBranch}`);
  
  if (fs.existsSync(path.join(worktreePath, 'package.json'))) {
    execSync(`cd ${worktreePath} && npm install`, { stdio: 'inherit' });
  }
  return worktreePath;
}

// 启动角色子代理，设置技能路径优先级
function startRoleSubagent(role, task, worktreePath) {
  return new Promise((resolve, reject) => {
    // 设置技能路径，优先角色自己的，然后主技能的，然后全局的
    const roleSkillsPath = path.join(ROLES_DIR, role.name, 'skills');
    const mainSkillsPath = path.join(BASE_DIR, 'skills');
    
    const env = {
      ...process.env,
      CLAUDE_SKILLS_DIR: roleSkillsPath,
      // 回退路径
      FALLBACK_SKILLS_DIR: `${mainSkillsPath}:${OPENCLAW_SKILLS}`
    };
    
    const subagent = spawn('npx', [
      'skills', 'subagent', role.name,
      '--task', JSON.stringify(task)
    ], { 
      stdio: 'pipe', 
      cwd: worktreePath,
      env: env
    });

    let output = '';
    subagent.stdout.on('data', data => output += data.toString());
    subagent.stderr.on('data', data => console.error(`[${role.name}] ERR: ${data}`));
    subagent.on('close', code => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`角色 ${role.name} 执行失败，退出码 ${code}`));
      }
    });
  });
}

// 调用安全网关子代理
async function runGateway(taskId, outputPath) {
  return new Promise((resolve, reject) => {
    const proc = spawn('npx', [
      'skills', 'subagent', 'security_gateway',
      '--task-id', taskId,
      '--output', outputPath
    ], { stdio: 'pipe' });
    
    let result = '';
    proc.stdout.on('data', data => result += data.toString());
    proc.stderr.on('data', data => console.error(`[gateway] ERR: ${data}`));
    proc.on('close', code => {
      if (code === 0) {
        try {
          resolve(JSON.parse(result));
        } catch (e) {
          reject(new Error('网关报告解析失败'));
        }
      } else {
        reject(new Error(`网关检查失败，退出码 ${code}`));
      }
    });
  });
}

// 实时汇报进度
function reportProgress(taskId, roleName, status, details) {
  const timestamp = new Date().toISOString();
  console.log(`[TEAM-REPORT][${timestamp}] ${roleName}|${taskId}|${status}|${details}`);
}

// 主函数
async function main(taskDescription) {
  console.log(`[Manager] 开始处理任务: ${taskDescription}`);
  
  // 1. 头脑风暴阶段
  console.log("[Manager] 启动需求澄清阶段...");
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const ask = (q) => new Promise(resolve => rl.question(q, resolve));
  
  const q1 = await ask("1. 这个功能的核心用户场景是什么？");
  const q2 = await ask("2. 是否需要考虑高并发或安全性？");
  const q3 = await ask("3. 你期望的技术栈是什么？");
  
  const designContent = `# 设计文档\n\n## 用户需求\n${taskDescription}\n\n## 头脑风暴记录\n1. ${q1}\n2. ${q2}\n3. ${q3}`;
  fs.writeFileSync(DESIGN_FILE, designContent);
  
  // 2. 创建主隔离工作区
  const timestamp = Date.now();
  const mainWorktree = path.join(process.cwd(), `../project-${timestamp}`);
  if (!fs.existsSync(mainWorktree)) {
    execSync(`git worktree add -b feature/task-${timestamp} ${mainWorktree} HEAD`);
    if (fs.existsSync(path.join(mainWorktree, 'package.json'))) {
      execSync(`cd ${mainWorktree} && npm install`, { stdio: 'inherit' });
    }
  }
  
  // 3. 加载角色技能
  const roles = loadRoles();
  console.log(`[Manager] 已发现 ${roles.length} 个角色技能: ${roles.map(r => r.name).join(', ')}`);
  
  // 4. 任务分解
  const tasks = [{
    id: 1,
    description: taskDescription,
    dependencies: [],
    assigned_role: null,
    status: 'pending',
    retries: 0
  }];
  
  // 匹配角色
  for (const task of tasks) {
    const matchedRole = matchRole(task.description, roles);
    task.assigned_role = matchedRole.name;
    console.log(`[Manager] 任务 ${task.id} 分配给角色 ${matchedRole.name}`);
  }
  fs.writeFileSync(TASKS_FILE, JSON.stringify(tasks, null, 2));
  
  // 5. 主控循环
  for (const task of tasks) {
    if (task.status !== 'pending') continue;
    
    const depsSatisfied = task.dependencies.every(depId => {
      const depTask = tasks.find(t => t.id === depId);
      return depTask && depTask.status === 'approved';
    });
    if (!depsSatisfied) continue;
    
    const role = roles.find(r => r.name === task.assigned_role);
    
    // 创建隔离工作区
    const worktreePath = createWorktree(role.name, task.id);
    console.log(`[Manager] 为角色 ${role.name} 创建隔离工作区: ${worktreePath}`);
    
    // 启动角色子代理
    let roleOutput;
    try {
      roleOutput = await startRoleSubagent(role, task, worktreePath);
      const outputFile = path.join(OUTPUTS_DIR, `${task.id}.json`);
      fs.writeFileSync(outputFile, roleOutput);
    } catch (err) {
      reportProgress(task.id, role.name, 'failed', `执行错误: ${err.message}`);
      if (task.retries < 2) {
        task.retries++;
        task.status = 'pending';
        fs.writeFileSync(TASKS_FILE, JSON.stringify(tasks, null, 2));
        continue;
      } else {
        reportProgress(task.id, role.name, 'blocked', '超过重试次数，请用户介入');
        break;
      }
    }
    
    // 安全网关检查
    let gatewayReport;
    try {
      gatewayReport = await runGateway(task.id, path.join(OUTPUTS_DIR, `${task.id}.json`));
    } catch (err) {
      reportProgress(task.id, role.name, 'rejected', `网关错误: ${err.message}`);
      if (task.retries < 2) {
        task.retries++;
        task.status = 'pending';
        fs.writeFileSync(TASKS_FILE, JSON.stringify(tasks, null, 2));
        continue;
      }
    }
    
    if (gatewayReport?.status === 'approved') {
      task.status = 'approved';
      reportProgress(task.id, role.name, 'approved', '网关通过');
    } else {
      task.status = 'rejected';
      const violations = gatewayReport?.violations?.map(v => `${v.file}:${v.line} ${v.message}`).join('; ') || '未知违规';
      reportProgress(task.id, role.name, 'rejected', violations);
      if (task.retries < 2) {
        task.retries++;
        task.status = 'pending';
        continue;
      }
    }
    fs.writeFileSync(TASKS_FILE, JSON.stringify(tasks, null, 2));
  }
  
  // 6. 完成
  const allApproved = tasks.every(t => t.status === 'approved');
  if (allApproved) {
    console.log("[Manager] 所有任务已完成并通过安全网关！");
    const answer = await ask("请选择下一步操作: (merge/pr/keep/discard) ");
    if (answer === 'merge') {
      execSync(`cd ${mainWorktree} && git checkout master && git merge feature/task-${timestamp} --no-ff`);
      console.log("已合并到 master 分支");
    } else if (answer === 'discard') {
      execSync(`git worktree remove ${mainWorktree} --force`);
      console.log("已丢弃工作区");
    }
  }
  
  rl.close();
}

// 入口
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("用法: node manager.js --task <任务描述>");
    process.exit(1);
  }
  const taskDesc = args[1];
  main(taskDesc).catch(console.error);
}
