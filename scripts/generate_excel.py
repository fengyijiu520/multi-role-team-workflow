#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
from pathlib import Path

# 允许访问的目录白名单，仅可访问/data/和/tmp/目录
ALLOWED_DIRS = ["/data/", "/tmp/"]

def validate_path(path: str) -> Path:
    """验证输入输出路径是否在允许的白名单目录内"""
    path_obj = Path(path).resolve()
    for allowed_dir in ALLOWED_DIRS:
        allowed_path = Path(allowed_dir).resolve()
        # 检查路径是否在允许目录下
        if allowed_path in path_obj.parents or path_obj == allowed_path:
            return path_obj
    raise PermissionError(f"路径 {path} 不在允许的访问范围内，仅允许访问 {ALLOWED_DIRS} 下的文件")

def main():
    parser = argparse.ArgumentParser(
        description="预批准的Excel生成工具，仅可访问/data/和/tmp/目录，支持透视表和基础图表生成"
    )
    # 基础参数
    parser.add_argument("input_path", help="输入数据文件路径（支持csv/xlsx，仅允许/data/或/tmp/下的文件）")
    parser.add_argument("output_path", help="输出Excel文件路径（仅允许/data/或/tmp/下的文件）")
    
    # 模板配置参数，由经理动态配置，文员仅可传入这些参数
    parser.add_argument("--pivot-index", help="透视表行字段，多个字段用逗号分隔（可选）")
    parser.add_argument("--pivot-columns", help="透视表列字段，多个字段用逗号分隔（可选）")
    parser.add_argument("--pivot-values", help="透视表值字段，多个字段用逗号分隔（可选）")
    parser.add_argument("--chart-type", help="生成的图表类型，支持bar(柱状图)/line(折线图)/pie(饼图)（可选）")
    
    # 严格禁止执行shell命令，本脚本不包含任何subprocess或系统调用相关代码
    
    try:
        args = parser.parse_args()
        
        # 验证输入输出路径
        input_path = validate_path(args.input_path)
        output_path = validate_path(args.output_path)
        
        # 读取输入数据
        if input_path.suffix.lower() == '.csv':
            df = pd.read_csv(input_path)
        elif input_path.suffix.lower() in ['.xlsx', '.xls']:
            df = pd.read_excel(input_path)
        else:
            raise ValueError(f"不支持的输入文件格式: {input_path.suffix}，仅支持csv、xlsx、xls格式")
        
        # 如果配置了透视表参数，生成透视表
        if args.pivot_index and args.pivot_values:
            index_fields = args.pivot_index.split(',')
            value_fields = args.pivot_values.split(',')
            column_fields = args.pivot_columns.split(',') if args.pivot_columns else None
            
            df = pd.pivot_table(
                df,
                index=index_fields,
                columns=column_fields,
                values=value_fields,
                aggfunc='sum'
            )
        
        # 生成Excel文件
        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # 写入数据到工作表
            df.to_excel(writer, sheet_name='数据', index=True)
            
            # 如果配置了图表参数，生成对应图表
            if args.chart_type:
                from openpyxl.chart import BarChart, LineChart, PieChart, Reference
                workbook = writer.book
                worksheet = writer.sheets['数据']
                
                # 根据类型创建图表
                if args.chart_type == 'bar':
                    chart = BarChart()
                elif args.chart_type == 'line':
                    chart = LineChart()
                elif args.chart_type == 'pie':
                    chart = PieChart()
                else:
                    raise ValueError(f"不支持的图表类型: {args.chart_type}，仅支持bar/line/pie")
                
                # 设置图表数据范围
                max_row = len(df) + 1
                max_col = len(df.columns) + 1
                data = Reference(worksheet, min_col=2, min_row=1, max_col=max_col, max_row=max_row)
                cats = Reference(worksheet, min_col=1, min_row=2, max_row=max_row)
                
                chart.add_data(data, titles_from_data=True)
                chart.set_categories(cats)
                chart.title = "数据统计图表"
                
                # 将图表添加到工作表
                worksheet.add_chart(chart, "H2")
        
        print(f"✅ Excel文件已成功生成: {output_path}")
        
    except PermissionError as e:
        print(f"❌ 权限错误: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
