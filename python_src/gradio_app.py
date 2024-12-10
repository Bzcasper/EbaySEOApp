import gradio as gr
import pandas as pd
import json
import sqlite3
from pathlib import Path
from typing import Dict, List
import plotly.express as px
import plotly.graph_objects as go

class EbayDashboard:
    def __init__(self):
        self.db_path = Path("/app/data/ebay_data.db")
        self.setup_database_connection()

    def setup_database_connection(self):
        """Setup database connection and create views if needed."""
        self.conn = sqlite3.connect(str(self.db_path))
        self.create_analytics_views()

    def create_analytics_views(self):
        """Create SQL views for analytics."""
        views = {
            "price_trends": """
                CREATE VIEW IF NOT EXISTS price_trends AS
                SELECT 
                    date(timestamp) as date,
                    AVG(price) as avg_price,
                    COUNT(*) as item_count
                FROM items
                GROUP BY date(timestamp)
            """,
            "category_stats": """
                CREATE VIEW IF NOT EXISTS category_stats AS
                SELECT 
                    category,
                    COUNT(*) as item_count,
                    AVG(price) as avg_price,
                    AVG(quality_score) as avg_quality
                FROM items i
                JOIN analysis a ON i.id = a.item_id
                GROUP BY category
            """
        }
        for view_name, query in views.items():
            self.conn.execute(query)
        self.conn.commit()

    def get_price_trends(self) -> go.Figure:
        """Generate price trends visualization."""
        df = pd.read_sql("SELECT * FROM price_trends", self.conn)
        fig = px.line(df, x='date', y='avg_price',
                     title='Average Price Trends Over Time')
        return fig

    def get_category_distribution(self) -> go.Figure:
        """Generate category distribution visualization."""
        df = pd.read_sql("SELECT * FROM category_stats", self.conn)
        fig = px.bar(df, x='category', y='item_count',
                    title='Items by Category')
        return fig

    def get_quality_analysis(self) -> go.Figure:
        """Generate quality score analysis."""
        df = pd.read_sql("""
            SELECT quality_score, price
            FROM items i
            JOIN analysis a ON i.id = a.item_id
        """, self.conn)
        fig = px.scatter(df, x='quality_score', y='price',
                        title='Price vs Quality Score')
        return fig

    def create_interface(self):
        """Create Gradio interface."""
        with gr.Blocks() as interface:
            gr.Markdown("# eBay SEO Analytics Dashboard")
            
            with gr.Tab("Price Analysis"):
                gr.Plot(self.get_price_trends)
                
            with gr.Tab("Category Analysis"):
                gr.Plot(self.get_category_distribution)
                
            with gr.Tab("Quality Analysis"):
                gr.Plot(self.get_quality_analysis)
                
            with gr.Tab("Data Explorer"):
                query = gr.Textbox(label="SQL Query")
                output = gr.DataFrame()
                
                def execute_query(query):
                    try:
                        return pd.read_sql(query, self.conn)
                    except Exception as e:
                        return pd.DataFrame({'error': [str(e)]})
                
                query.submit(execute_query, query, output)

        return interface

def main():
    dashboard = EbayDashboard()
    interface = dashboard.create_interface()
    interface.launch(server_name="0.0.0.0", server_port=7860)

if __name__ == "__main__":
    main()