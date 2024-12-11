#!/usr/bin/env python3
import os
import json
import shutil
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import pandas as pd

class DatasetCreator:
    def __init__(self, input_path: str = "./data/raw",
                 output_path: str = "./data/processed",
                 format: str = "json",
                 batch_size: int = 100,
                 include_images: bool = False):
        self.input_path = Path(input_path)
        self.output_path = Path(output_path)
        self.format = format.lower()
        self.batch_size = batch_size
        self.include_images = include_images
        self.setup_logging()

    def setup_logging(self):
        """Initialize logging configuration."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('dataset_creation.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def initialize_directories(self):
        """Create necessary directories if they don't exist."""
        self.input_path.mkdir(parents=True, exist_ok=True)
        self.output_path.mkdir(parents=True, exist_ok=True)
        self.logger.info(f"Initialized directories: {self.input_path}, {self.output_path}")

    def process_images(self, image_path: Path):
        """Process images if required."""
        if self.include_images:
            self.logger.info(f"Processing images from: {image_path}")
            images = list(image_path.glob("**/*.jpg"))
            for image in images:
                try:
                    # Add image processing logic here
                    self.logger.info(f"Processing image: {image.name}")
                except Exception as e:
                    self.logger.error(f"Error processing image {image.name}: {str(e)}")

    def create_dataset(self, input_data: Path, output_file: Path):
        """Create the dataset from input data."""
        try:
            self.logger.info(f"Creating dataset from: {input_data}")
            
            # Read input data
            with open(input_data) as f:
                data = json.load(f)
            
            # Process data in batches
            processed_data = []
            for i in range(0, len(data), self.batch_size):
                batch = data[i:i + self.batch_size]
                
                for item in batch:
                    processed_item = {
                        'id': item.get('id'),
                        'title': item.get('title'),
                        'price': item.get('price'),
                        'description': item.get('description'),
                        'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    }
                    processed_data.append(processed_item)
            
            # Save dataset in specified format
            if self.format == "json":
                with open(output_file, 'w') as f:
                    json.dump(processed_data, f, indent=2)
            elif self.format == "csv":
                df = pd.DataFrame(processed_data)
                df.to_csv(output_file, index=False)
            else:
                raise ValueError(f"Unsupported format: {self.format}")
            
            self.logger.info(f"Dataset created successfully: {output_file}")
        except Exception as e:
            self.logger.error(f"Error creating dataset: {str(e)}")
            raise

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Create datasets from raw data')
    parser.add_argument('--input-path', default='./data/raw', help='Input data path')
    parser.add_argument('--output-path', default='./data/processed', help='Output data path')
    parser.add_argument('--format', default='json', choices=['json', 'csv'], help='Output format')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size for processing')
    parser.add_argument('--include-images', action='store_true', help='Include image processing')
    
    args = parser.parse_args()
    
    creator = DatasetCreator(
        input_path=args.input_path,
        output_path=args.output_path,
        format=args.format,
        batch_size=args.batch_size,
        include_images=args.include_images
    )
    
    try:
        creator.initialize_directories()
        
        if args.include_images:
            creator.process_images(Path(args.input_path))
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = Path(args.output_path) / f"dataset_{timestamp}.{args.format}"
        
        creator.create_dataset(
            Path(args.input_path) / "data.json",
            output_file
        )
        
    except Exception as e:
        logging.error(f"Dataset creation failed: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()