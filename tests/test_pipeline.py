import unittest
import sys
import os
import json
import sqlite3
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='test_pipeline.log'
)
logger = logging.getLogger(__name__)

class TestPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Set up test environment"""
        cls.test_dir = Path("tests/test_data")
        cls.test_dir.mkdir(parents=True, exist_ok=True)
        
        # Create test database
        cls.db_path = cls.test_dir / "test.db"
        cls.init_test_db()
        
        # Create test data
        cls.create_test_data()

    @classmethod
    def init_test_db(cls):
        """Initialize test database"""
        try:
            conn = sqlite3.connect(cls.db_path)
            cursor = conn.cursor()
            
            # Create test tables
            cursor.executescript("""
                CREATE TABLE IF NOT EXISTS items (
                    id INTEGER PRIMARY KEY,
                    title TEXT NOT NULL,
                    price REAL,
                    url TEXT UNIQUE,
                    image_url TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                );
                
                CREATE TABLE IF NOT EXISTS seo_data (
                    id INTEGER PRIMARY KEY,
                    item_id INTEGER,
                    description TEXT,
                    keywords TEXT,
                    FOREIGN KEY(item_id) REFERENCES items(id)
                );
            """)
            
            conn.commit()
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise
        finally:
            if conn:
                conn.close()

    @classmethod
    def create_test_data(cls):
        """Create test data files"""
        test_items = [
            {
                "title": "Test Product 1",
                "price": 99.99,
                "url": "http://test.com/1",
                "image_url": "http://test.com/img1.jpg"
            },
            {
                "title": "Test Product 2",
                "price": 149.99,
                "url": "http://test.com/2",
                "image_url": "http://test.com/img2.jpg"
            }
        ]
        
        # Save test data
        with open(cls.test_dir / "test_data.json", "w") as f:
            json.dump(test_items, f)

    def test_database_operations(self):
        """Test database operations"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Test insertion
            cursor.execute("""
                INSERT INTO items (title, price, url, image_url)
                VALUES (?, ?, ?, ?)
            """, ("Test Item", 99.99, "http://test.com", "http://test.com/img.jpg"))
            
            conn.commit()
            
            # Test retrieval
            cursor.execute("SELECT * FROM items WHERE title = ?", ("Test Item",))
            result = cursor.fetchone()
            
            self.assertIsNotNone(result)
            self.assertEqual(result[1], "Test Item")
            self.assertEqual(float(result[2]), 99.99)
            
        except Exception as e:
            logger.error(f"Database test failed: {e}")
            raise
        finally:
            if conn:
                conn.close()

    def test_scrape_ebay(self):
        """Test eBay scraping functionality"""
        try:
            # Import the Lua script using lupa
            import lupa
            lua = lupa.LuaRuntime()
            
            with open("lua-scripts/scrape_ebay.lua", "r") as f:
                scrape_script = f.read()
            
            # Execute the Lua script
            scraper = lua.execute(scrape_script)
            
            # Test scraping function
            result = scraper.scrape_listings(["test item"], {"max_pages": 1})
            
            self.assertIsNotNone(result)
            self.assertTrue(len(result) > 0)
            
        except Exception as e:
            logger.error(f"Scraping test failed: {e}")
            self.fail(f"Scraping test failed: {e}")

    def test_seo_generation(self):
        """Test SEO description generation"""
        try:
            import lupa
            lua = lupa.LuaRuntime()
            
            with open("lua-scripts/generate_seo_desc.lua", "r") as f:
                seo_script = f.read()
            
            seo_generator = lua.execute(seo_script)
            
            test_item = {
                "title": "Test Product",
                "description": "Test description",
                "price": 99.99
            }
            
            result = seo_generator.generate(test_item)
            
            self.assertIsNotNone(result)
            self.assertTrue("description" in result)
            self.assertTrue("keywords" in result)
            
        except Exception as e:
            logger.error(f"SEO generation test failed: {e}")
            self.fail(f"SEO generation test failed: {e}")

    def test_image_processing(self):
        """Test image processing functionality"""
        try:
            # Create test image
            from PIL import Image
            import numpy as np
            
            test_image = Image.fromarray(np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8))
            test_image_path = self.test_dir / "test_image.jpg"
            test_image.save(test_image_path)
            
            import lupa
            lua = lupa.LuaRuntime()
            
            with open("lua-scripts/analyze_image.lua", "r") as f:
                image_script = f.read()
            
            image_analyzer = lua.execute(image_script)
            
            result = image_analyzer.analyze(str(test_image_path))
            
            self.assertIsNotNone(result)
            self.assertTrue("features" in result)
            
        except Exception as e:
            logger.error(f"Image processing test failed: {e}")
            self.fail(f"Image processing test failed: {e}")

    def test_pipeline_integration(self):
        """Test full pipeline integration"""
        try:
            import lupa
            lua = lupa.LuaRuntime()
            
            with open("lua-scripts/pipeline.lua", "r") as f:
                pipeline_script = f.read()
            
            pipeline = lua.execute(pipeline_script)
            
            result = pipeline.run_pipeline()
            
            self.assertTrue(result)
            
        except Exception as e:
            logger.error(f"Pipeline integration test failed: {e}")
            self.fail(f"Pipeline integration test failed: {e}")

    def tearDown(self):
        """Clean up test data"""
        try:
            import shutil
            shutil.rmtree(self.test_dir)
        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

if __name__ == "__main__":
    unittest.main(verbosity=2)