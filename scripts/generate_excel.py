#!/usr/bin/env python3
import pandas as pd
import argparse
import os

def generate_excel(input_file, output_file, has_pivot=False):
    """
    安全的Excel生成脚本，仅处理预定义的操作
    """
    # 限制输入输出目录，防止越权
    allowed_dirs = ['/data/', '/tmp/', os.path.expanduser('~/')]
    if not any(output_file.startswith(d) for d in allowed_dirs):
        raise PermissionError("输出文件必须放在 /data/ 或 /tmp/ 目录下")
    
    # 读取输入
    df = pd.read_csv(input_file)
    
    # 生成透视表（如果需要）
    if has_pivot:
        df = df.pivot_table(index=df.columns[0], values=df.columns[1], aggfunc='sum')
    
    # 写入Excel
    df.to_excel(output_file, index=False)
    print(f"Excel文件已生成: {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='安全的Excel生成工具')
    parser.add_argument('input', help='输入CSV文件')
    parser.add_argument('output', help='输出Excel文件')
    parser.add_argument('--pivot', action='store_true', help='是否生成透视表')
    
    args = parser.parse_args()
    generate_excel(args.input, args.output, args.pivot)
