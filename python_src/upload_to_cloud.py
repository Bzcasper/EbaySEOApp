from google.cloud import storage
from google.cloud import vision
import os
import json
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

class CloudUploader:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.bucket_name = os.getenv("CLOUD_STORAGE_BUCKET")
        self.setup_clients()

    def setup_clients(self):
        """Initialize Google Cloud clients."""
        try:
            self.storage_client = storage.Client()
            self.vision_client = vision.ImageAnnotatorClient()
            self.bucket = self.storage_client.bucket(self.bucket_name)
        except Exception as e:
            self.logger.error(f"Failed to initialize cloud clients: {str(e)}")
            raise

    def upload_file(self, file_path: str, destination_blob_name: Optional[str] = None) -> str:
        """Upload a file to Google Cloud Storage."""
        try:
            if not destination_blob_name:
                destination_blob_name = f"uploads/{datetime.now().strftime('%Y%m%d_%H%M%S')}/{Path(file_path).name}"

            blob = self.bucket.blob(destination_blob_name)
            blob.upload_from_filename(file_path)

            return f"gs://{self.bucket_name}/{destination_blob_name}"
        except Exception as e:
            self.logger.error(f"Upload failed for {file_path}: {str(e)}")
            raise

    def analyze_image(self, image_path: str) -> Dict:
        """Analyze image using Google Cloud Vision API."""
        try:
            with open(image_path, 'rb') as image_file:
                content = image_file.read()

            image = vision.Image(content=content)
            
            # Perform multiple types of analysis
            labels = self.vision_client.label_detection(image=image)
            objects = self.vision_client.object_localization(image=image)
            safe_search = self.vision_client.safe_search_detection(image=image)
            
            # Compile results
            results = {
                'labels': [
                    {'description': label.description, 'score': label.score}
                    for label in labels.label_annotations
                ],
                'objects': [
                    {'name': obj.name, 'confidence': obj.score}
                    for obj in objects.localized_object_annotations
                ],
                'safe_search': {
                    'adult': safe_search.safe_search_annotation.adult.name,
                    'violence': safe_search.safe_search_annotation.violence.name,
                    'racy': safe_search.safe_search_annotation.racy.name
                }
            }
            
            return results
        except Exception as e:
            self.logger.error(f"Image analysis failed for {image_path}: {str(e)}")
            raise

    def upload_dataset(self, data_path: str, metadata: Dict = None) -> str:
        """Upload a complete dataset with metadata."""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            dataset_path = f"datasets/{timestamp}"
            
            # Upload main data file
            data_blob_name = f"{dataset_path}/data.json"
            self.upload_file(data_path, data_blob_name)
            
            # Upload metadata if provided
            if metadata:
                metadata_blob = self.bucket.blob(f"{dataset_path}/metadata.json")
                metadata_blob.upload_from_string(
                    json.dumps(metadata, indent=2),
                    content_type='application/json'
                )
            
            return f"gs://{self.bucket_name}/{dataset_path}"
        except Exception as e:
            self.logger.error(f"Dataset upload failed: {str(e)}")
            raise

    def backup_database(self, db_path: str) -> str:
        """Upload database backup to cloud storage."""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_blob_name = f"backups/{timestamp}/ebay_data.db"
            
            return self.upload_file(db_path, backup_blob_name)
        except Exception as e:
            self.logger.error(f"Database backup failed: {str(e)}")
            raise

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    uploader = CloudUploader()
    
    # Example usage
    try:
        result = uploader.backup_database("/app/data/ebay_data.db")
        print(f"Backup successful: {result}")
    except Exception as e:
        print(f"Backup failed: {str(e)}")