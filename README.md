# multi-role-team-workflow

多角色团队工作流 - 适配 OpenClaw 框架的 AI 团队协作技能

## 安装

```bash
unzip multi-role-team-workflow.zip
cd multi-role-team-workflow
chmod +x install.sh
./install.sh
```

## 依赖

- Node.js 16+
- Git
- wget
- unzip
- openclaw 环境

## 管理工具

你可以使用 `team-cli.sh` 来管理你的技能和角色：
```bash
./team-cli.sh
```

支持的操作：
1. 查看当前所有角色
2. 增加新角色（支持纯净/基础/完整三种类型）
3. 删除用户自定义角色
4. 检查并安装依赖技能
5. 更新技能到最新版本

## 快速开始

1. 在项目根目录下，启动团队工作流：
    ```Plain Text
    /team-start 实现用户登录功能，包括JWT验证和错误处理
    ```

2. 技能会自动启动经理子代理，按照工作流执行：
    - 需求澄清
    - 任务分解
    - 角色分配
    - 并行执行
    - 安全审查
    - 结果合并

## 角色技能优先级
每个角色都有自己的独立技能库，技能加载优先级：
1.  **角色本地技能库**：`./roles/<角色>/skills/`
2.  **主技能本地依赖**：`./skills/`
3.  **全局 OpenClaw 技能库**：`openclaw/skills/`

## 自定义角色

你可以通过 `team-cli.sh` 轻松添加新角色，也可以手动在 `roles/` 目录下创建新的角色目录，技能会自动发现。

## 安全规则

编辑 `security-rules.json` 调整安全检查规则。

## 更新技能

运行 `./team-cli.sh` 选择更新选项，即可自动检查并更新到最新版本。

## 许可证

MIT
