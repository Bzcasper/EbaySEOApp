import torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqGeneration
import json
import logging
from typing import Dict, List, Optional
from .config import config

class SEOGenerator:
    def __init__(self):
        self.model_name = config.get('seo', 'model', 'name')
        self.max_length = config.get('seo', 'model', 'max_length')
        self.batch_size = config.get('seo', 'model', 'batch_size')
        
class SEOGenerator:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.model_name = "t5-base"  # or your preferred model
        try:
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            self.model = AutoModelForSeq2SeqGeneration.from_pretrained(self.model_name)
        except Exception as e:
            self.logger.error(f"Failed to load model: {str(e)}")
            raise

    def generate_keywords(self, features: Dict) -> List[str]:
        """Generate SEO keywords from item features."""
        try:
            # Combine relevant features
            feature_text = f"{features['title']} {features.get('brand', '')} {features.get('category', '')}"
            if 'visual_attributes' in features:
                feature_text += ' ' + ' '.join(features['visual_attributes'])

            # Prepare input for model
            input_text = f"generate keywords: {feature_text}"
            inputs = self.tokenizer(input_text, return_tensors="pt", max_length=512, truncation=True)

            # Generate keywords
            outputs = self.model.generate(
                inputs.input_ids,
                max_length=50,
                num_return_sequences=1,
                num_beams=4
            )

            keywords = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            return keywords.split(',')
        except Exception as e:
            self.logger.error(f"Keyword generation failed: {str(e)}")
            return []

    def generate_description(self, features: Dict, keywords: List[str]) -> str:
        """Generate SEO-optimized description."""
        try:
            # Combine features and keywords
            context = {
                'title': features['title'],
                'price': features.get('price', ''),
                'condition': features.get('condition', ''),
                'keywords': ', '.join(keywords[:5])  # Use top 5 keywords
            }

            # Create prompt for description generation
            prompt = (
                f"Generate SEO description for: {context['title']}\n"
                f"Price: {context['price']}\n"
                f"Condition: {context['condition']}\n"
                f"Keywords: {context['keywords']}"
            )

            inputs = self.tokenizer(prompt, return_tensors="pt", max_length=512, truncation=True)
            outputs = self.model.generate(
                inputs.input_ids,
                max_length=200,
                num_return_sequences=1,
                num_beams=4,
                temperature=0.7
            )

            description = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            return description
        except Exception as e:
            self.logger.error(f"Description generation failed: {str(e)}")
            return ""

    def optimize_metadata(self, description: str, keywords: List[str]) -> Dict:
        """Create optimized metadata for SEO."""
        return {
            'meta_description': description[:160],  # Standard meta description length
            'meta_keywords': ','.join(keywords[:10]),  # Top 10 keywords
            'suggested_tags': keywords[:5],  # Top 5 tags
            'seo_score': self._calculate_seo_score(description, keywords)
        }

    def _calculate_seo_score(self, description: str, keywords: List[str]) -> float:
        """Calculate SEO score based on description and keywords."""
        score = 0.0
        try:
            # Check keyword density
            desc_lower = description.lower()
            for keyword in keywords:
                if keyword.lower() in desc_lower:
                    score += 1

            # Length checks
            if 100 <= len(description) <= 160:
                score += 2
            elif len(description) > 160:
                score += 1

            # Normalize score to 0-100
            score = min(100, (score / (len(keywords) + 2)) * 100)
            return round(score, 2)
        except Exception as e:
            self.logger.error(f"SEO score calculation failed: {str(e)}")
            return 0.0