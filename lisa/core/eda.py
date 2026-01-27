"""
LISA Exploratory Data Analysis (EDA) Module

Automatically discovers datasets, analyzes distributions, detects issues,
and generates comprehensive EDA reports with visualizations.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
import warnings

warnings.filterwarnings('ignore')


class EDA:
    """Exploratory Data Analysis toolkit"""

    def __init__(self, data_dir: Path):
        """
        Initialize EDA

        Args:
            data_dir: Path to directory containing datasets
        """
        self.data_dir = Path(data_dir)
        self.datasets = {}
        self.profiles = {}

    def discover_datasets(self) -> List[Dict[str, Any]]:
        """
        Discover all datasets in data directory

        Returns:
            List of dataset information dictionaries
        """
        datasets = []

        if not self.data_dir.exists():
            return datasets

        # Supported file types
        patterns = [
            ('*.csv', 'csv'),
            ('*.parquet', 'parquet'),
            ('*.xlsx', 'excel'),
            ('*.json', 'json'),
            ('*.feather', 'feather')
        ]

        for pattern, file_type in patterns:
            for file_path in self.data_dir.glob(pattern):
                size_mb = file_path.stat().st_size / (1024 * 1024)

                dataset_info = {
                    'name': file_path.stem,
                    'path': str(file_path),
                    'type': file_type,
                    'size_mb': round(size_mb, 2)
                }

                datasets.append(dataset_info)

        return datasets

    def load_dataset(
        self,
        file_path: str,
        sample_size: Optional[int] = None,
        **kwargs
    ) -> pd.DataFrame:
        """
        Load a dataset with automatic format detection

        Args:
            file_path: Path to dataset file
            sample_size: Optional sample size for large datasets
            **kwargs: Additional arguments for pandas readers

        Returns:
            DataFrame
        """
        file_path = Path(file_path)
        suffix = file_path.suffix.lower()

        # Determine if we should sample
        size_mb = file_path.stat().st_size / (1024 * 1024)
        use_sample = sample_size or (size_mb > 500)  # Sample if > 500MB

        try:
            if suffix == '.csv':
                if use_sample and isinstance(use_sample, int):
                    df = pd.read_csv(file_path, nrows=use_sample, **kwargs)
                else:
                    df = pd.read_csv(file_path, **kwargs)

            elif suffix == '.parquet':
                df = pd.read_parquet(file_path, **kwargs)
                if use_sample and isinstance(use_sample, int):
                    df = df.sample(n=min(use_sample, len(df)), random_state=42)

            elif suffix in ['.xlsx', '.xls']:
                df = pd.read_excel(file_path, **kwargs)
                if use_sample and isinstance(use_sample, int):
                    df = df.sample(n=min(use_sample, len(df)), random_state=42)

            elif suffix == '.json':
                df = pd.read_json(file_path, **kwargs)
                if use_sample and isinstance(use_sample, int):
                    df = df.sample(n=min(use_sample, len(df)), random_state=42)

            elif suffix == '.feather':
                df = pd.read_feather(file_path, **kwargs)
                if use_sample and isinstance(use_sample, int):
                    df = df.sample(n=min(use_sample, len(df)), random_state=42)

            else:
                raise ValueError(f"Unsupported file format: {suffix}")

            # Cache the dataset
            self.datasets[file_path.stem] = df

            return df

        except Exception as e:
            raise RuntimeError(f"Failed to load {file_path}: {str(e)}")

    def profile_dataset(self, df: pd.DataFrame, name: str = "dataset") -> Dict[str, Any]:
        """
        Create comprehensive profile of a dataset

        Args:
            df: DataFrame to profile
            name: Name for the dataset

        Returns:
            Dictionary with profile information
        """
        profile = {
            'name': name,
            'shape': df.shape,
            'memory_usage_mb': df.memory_usage(deep=True).sum() / (1024 * 1024),
            'dtypes': df.dtypes.value_counts().to_dict(),
            'columns': {},
            'missing_values': {},
            'duplicates': {
                'count': df.duplicated().sum(),
                'percentage': (df.duplicated().sum() / len(df)) * 100
            }
        }

        # Profile each column
        for col in df.columns:
            col_profile = self._profile_column(df[col])
            profile['columns'][col] = col_profile

            # Track missing values
            missing_count = df[col].isna().sum()
            if missing_count > 0:
                profile['missing_values'][col] = {
                    'count': int(missing_count),
                    'percentage': round((missing_count / len(df)) * 100, 2)
                }

        # Cache profile
        self.profiles[name] = profile

        return profile

    def _profile_column(self, series: pd.Series) -> Dict[str, Any]:
        """Profile a single column"""
        profile = {
            'dtype': str(series.dtype),
            'missing': int(series.isna().sum()),
            'unique': int(series.nunique()),
            'unique_percentage': round((series.nunique() / len(series)) * 100, 2)
        }

        # Numeric columns
        if pd.api.types.is_numeric_dtype(series):
            profile.update({
                'mean': float(series.mean()) if not series.isna().all() else None,
                'std': float(series.std()) if not series.isna().all() else None,
                'min': float(series.min()) if not series.isna().all() else None,
                'max': float(series.max()) if not series.isna().all() else None,
                'median': float(series.median()) if not series.isna().all() else None,
                'q25': float(series.quantile(0.25)) if not series.isna().all() else None,
                'q75': float(series.quantile(0.75)) if not series.isna().all() else None,
            })

        # Categorical/Object columns
        elif pd.api.types.is_object_dtype(series) or pd.api.types.is_categorical_dtype(series):
            value_counts = series.value_counts()
            profile.update({
                'most_common': value_counts.head(5).to_dict(),
                'cardinality': 'high' if series.nunique() > 50 else 'medium' if series.nunique() > 10 else 'low'
            })

        # Datetime columns
        elif pd.api.types.is_datetime64_any_dtype(series):
            profile.update({
                'min_date': str(series.min()),
                'max_date': str(series.max()),
                'range_days': (series.max() - series.min()).days if not series.isna().all() else None
            })

        return profile

    def analyze_correlations(
        self,
        df: pd.DataFrame,
        threshold: float = 0.7,
        method: str = 'pearson'
    ) -> Dict[str, Any]:
        """
        Analyze correlations between numeric features

        Args:
            df: DataFrame
            threshold: Threshold for high correlation
            method: Correlation method (pearson, spearman, kendall)

        Returns:
            Dictionary with correlation analysis
        """
        numeric_cols = df.select_dtypes(include=[np.number]).columns

        if len(numeric_cols) < 2:
            return {'error': 'Not enough numeric columns for correlation analysis'}

        # Compute correlation matrix
        corr_matrix = df[numeric_cols].corr(method=method)

        # Find high correlations
        high_corr = []
        for i in range(len(corr_matrix.columns)):
            for j in range(i + 1, len(corr_matrix.columns)):
                corr_value = corr_matrix.iloc[i, j]
                if abs(corr_value) >= threshold:
                    high_corr.append({
                        'feature_1': corr_matrix.columns[i],
                        'feature_2': corr_matrix.columns[j],
                        'correlation': round(corr_value, 3)
                    })

        return {
            'correlation_matrix': corr_matrix.to_dict(),
            'high_correlations': high_corr,
            'threshold': threshold,
            'method': method
        }

    def detect_outliers(
        self,
        df: pd.DataFrame,
        method: str = 'iqr',
        threshold: float = 1.5
    ) -> Dict[str, Any]:
        """
        Detect outliers in numeric columns

        Args:
            df: DataFrame
            method: Detection method ('iqr' or 'zscore')
            threshold: Threshold for outlier detection

        Returns:
            Dictionary with outlier information
        """
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        outliers = {}

        for col in numeric_cols:
            series = df[col].dropna()

            if len(series) == 0:
                continue

            if method == 'iqr':
                q1 = series.quantile(0.25)
                q3 = series.quantile(0.75)
                iqr = q3 - q1
                lower_bound = q1 - threshold * iqr
                upper_bound = q3 + threshold * iqr

                outlier_mask = (series < lower_bound) | (series > upper_bound)
                outlier_count = outlier_mask.sum()

            elif method == 'zscore':
                z_scores = np.abs((series - series.mean()) / series.std())
                outlier_mask = z_scores > threshold
                outlier_count = outlier_mask.sum()

            else:
                raise ValueError(f"Unknown method: {method}")

            if outlier_count > 0:
                outliers[col] = {
                    'count': int(outlier_count),
                    'percentage': round((outlier_count / len(series)) * 100, 2)
                }

        return {
            'method': method,
            'threshold': threshold,
            'outliers_by_column': outliers
        }

    def suggest_preprocessing(self, profile: Dict[str, Any]) -> List[str]:
        """
        Suggest preprocessing steps based on profile

        Args:
            profile: Dataset profile from profile_dataset()

        Returns:
            List of preprocessing suggestions
        """
        suggestions = []

        # Check for missing values
        if profile.get('missing_values'):
            suggestions.append(
                f"Handle missing values in {len(profile['missing_values'])} columns: "
                f"{', '.join(list(profile['missing_values'].keys())[:5])}"
            )

        # Check for duplicates
        if profile['duplicates']['count'] > 0:
            suggestions.append(
                f"Remove {profile['duplicates']['count']} duplicate rows "
                f"({profile['duplicates']['percentage']:.2f}%)"
            )

        # Check for high cardinality categorical features
        high_card_cols = []
        for col, col_profile in profile['columns'].items():
            if col_profile.get('cardinality') == 'high':
                high_card_cols.append(col)

        if high_card_cols:
            suggestions.append(
                f"Consider encoding or reducing high cardinality features: "
                f"{', '.join(high_card_cols[:5])}"
            )

        # Check for imbalanced numeric ranges
        numeric_ranges = []
        for col, col_profile in profile['columns'].items():
            if 'min' in col_profile and 'max' in col_profile:
                if col_profile['max'] is not None and col_profile['min'] is not None:
                    range_val = col_profile['max'] - col_profile['min']
                    if range_val > 1000:
                        numeric_ranges.append(col)

        if numeric_ranges:
            suggestions.append(
                f"Consider scaling numeric features with large ranges: "
                f"{', '.join(numeric_ranges[:5])}"
            )

        return suggestions

    def generate_eda_report(
        self,
        df: pd.DataFrame,
        name: str = "dataset"
    ) -> Dict[str, Any]:
        """
        Generate complete EDA report

        Args:
            df: DataFrame to analyze
            name: Dataset name

        Returns:
            Comprehensive EDA report
        """
        report = {
            'dataset_name': name,
            'profile': self.profile_dataset(df, name),
            'correlations': self.analyze_correlations(df),
            'outliers': self.detect_outliers(df),
            'suggestions': []
        }

        # Add preprocessing suggestions
        report['suggestions'] = self.suggest_preprocessing(report['profile'])

        return report

    def export_report_to_markdown(self, report: Dict[str, Any], output_path: Path):
        """
        Export EDA report to Markdown

        Args:
            report: EDA report dictionary
            output_path: Path to save markdown file
        """
        lines = []

        lines.append(f"# EDA Report: {report['dataset_name']}")
        lines.append("")
        lines.append(f"**Generated**: {pd.Timestamp.now()}")
        lines.append("")
        lines.append("---")
        lines.append("")

        # Dataset Overview
        profile = report['profile']
        lines.append("## Dataset Overview")
        lines.append("")
        lines.append(f"- **Rows**: {profile['shape'][0]:,}")
        lines.append(f"- **Columns**: {profile['shape'][1]}")
        lines.append(f"- **Memory**: {profile['memory_usage_mb']:.2f} MB")
        lines.append(f"- **Duplicates**: {profile['duplicates']['count']} ({profile['duplicates']['percentage']:.2f}%)")
        lines.append("")

        # Missing Values
        if profile.get('missing_values'):
            lines.append("## Missing Values")
            lines.append("")
            lines.append("| Column | Missing Count | Percentage |")
            lines.append("|--------|---------------|------------|")
            for col, info in sorted(
                profile['missing_values'].items(),
                key=lambda x: x[1]['count'],
                reverse=True
            ):
                lines.append(f"| {col} | {info['count']} | {info['percentage']:.2f}% |")
            lines.append("")

        # High Correlations
        if report['correlations'].get('high_correlations'):
            lines.append("## High Correlations")
            lines.append("")
            for corr in report['correlations']['high_correlations']:
                lines.append(
                    f"- **{corr['feature_1']}** ↔ **{corr['feature_2']}**: "
                    f"{corr['correlation']:.3f}"
                )
            lines.append("")

        # Outliers
        if report['outliers'].get('outliers_by_column'):
            lines.append("## Outliers")
            lines.append("")
            lines.append("| Column | Outlier Count | Percentage |")
            lines.append("|--------|---------------|------------|")
            for col, info in report['outliers']['outliers_by_column'].items():
                lines.append(f"| {col} | {info['count']} | {info['percentage']:.2f}% |")
            lines.append("")

        # Preprocessing Suggestions
        if report['suggestions']:
            lines.append("## Preprocessing Suggestions")
            lines.append("")
            for i, suggestion in enumerate(report['suggestions'], 1):
                lines.append(f"{i}. {suggestion}")
            lines.append("")

        # Write file
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            f.write('\n'.join(lines))

    def __repr__(self) -> str:
        return f"EDA(data_dir={self.data_dir}, datasets={len(self.datasets)})"
