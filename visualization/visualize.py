import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import sqlite3
from pathlib import Path
import json
from typing import Dict, List

class DataVisualizer:
    def __init__(self, db_path: str = "/app/data/ebay_data.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)

    def create_price_trend_chart(self) -> go.Figure:
        """Create price trend visualization."""
        query = """
        SELECT date(timestamp) as date, 
               AVG(price) as avg_price,
               COUNT(*) as count
        FROM items
        GROUP BY date(timestamp)
        ORDER BY date
        """
        df = pd.read_sql_query(query, self.conn)
        
        fig = px.line(df, x='date', y='avg_price',
                     title='Average Price Trends Over Time',
                     labels={'avg_price': 'Average Price ($)',
                            'date': 'Date'})
        return fig

    def create_category_distribution(self) -> go.Figure:
        """Create category distribution chart."""
        query = """
        SELECT category,
               COUNT(*) as count,
               AVG(price) as avg_price
        FROM items
        GROUP BY category
        """
        df = pd.read_sql_query(query, self.conn)
        
        fig = px.bar(df, x='category', y='count',
                    title='Items by Category',
                    color='avg_price',
                    labels={'count': 'Number of Items',
                           'category': 'Category',
                           'avg_price': 'Average Price ($)'})
        return fig

    def create_seo_effectiveness_chart(self) -> go.Figure:
        """Create SEO effectiveness visualization."""
        query = """
        SELECT i.title,
               i.price,
               s.quality_score,
               s.click_through_rate
        FROM items i
        JOIN seo_metrics s ON i.id = s.item_id
        """
        df = pd.read_sql_query(query, self.conn)
        
        fig = px.scatter(df, x='quality_score', y='click_through_rate',
                        size='price', hover_data=['title'],
                        title='SEO Effectiveness vs Quality Score',
                        labels={'quality_score': 'SEO Quality Score',
                               'click_through_rate': 'Click-through Rate (%)',
                               'price': 'Price ($)'})
        return fig

    def generate_html_report(self, output_path: str):
        """Generate complete HTML report with all visualizations."""
        charts = [
            self.create_price_trend_chart(),
            self.create_category_distribution(),
            self.create_seo_effectiveness_chart()
        ]
        
        html_content = """
        <html>
        <head>
            <title>eBay SEO Analytics Report</title>
            <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
        </head>
        <body class="bg-gray-100 p-8">
            <div class="max-w-7xl mx-auto">
                <h1 class="text-3xl font-bold mb-8">eBay SEO Analytics Report</h1>
                <div class="grid gap-8">
        """
        
        for chart in charts:
            html_content += f"""
                <div class="bg-white p-6 rounded-lg shadow-lg">
                    {chart.to_html(full_html=False, include_plotlyjs='cdn')}
                </div>
            """
        
        html_content += """
                </div>
            </div>
        </body>
        </html>
        """
        
        with open(output_path, 'w') as f:
            f.write(html_content)