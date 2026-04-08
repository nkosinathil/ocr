import io
import logging
from datetime import timedelta

from minio import Minio
from minio.error import S3Error

from app.config import get_settings

logger = logging.getLogger(__name__)


class MinIOService:
    def __init__(self):
        settings = get_settings()
        self.client = Minio(
            endpoint=settings.MINIO_ENDPOINT,
            access_key=settings.MINIO_ACCESS_KEY,
            secret_key=settings.MINIO_SECRET_KEY,
            secure=settings.MINIO_USE_SSL,
        )
        self.bucket_uploads = settings.MINIO_BUCKET_UPLOADS
        self.bucket_results = settings.MINIO_BUCKET_RESULTS

    def ensure_buckets(self) -> None:
        for bucket_name in (self.bucket_uploads, self.bucket_results):
            try:
                if not self.client.bucket_exists(bucket_name):
                    self.client.make_bucket(bucket_name)
                    logger.info("Created MinIO bucket: %s", bucket_name)
                else:
                    logger.debug("MinIO bucket already exists: %s", bucket_name)
            except S3Error:
                logger.exception("Failed to ensure bucket: %s", bucket_name)
                raise

    def upload_file(
        self,
        bucket: str,
        object_name: str,
        file_data: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        data_stream = io.BytesIO(file_data)
        try:
            self.client.put_object(
                bucket_name=bucket,
                object_name=object_name,
                data=data_stream,
                length=len(file_data),
                content_type=content_type,
            )
            logger.info("Uploaded %s to bucket %s (%d bytes)", object_name, bucket, len(file_data))
            return object_name
        except S3Error:
            logger.exception("Failed to upload %s to %s", object_name, bucket)
            raise

    def download_file(self, bucket: str, object_name: str) -> bytes:
        try:
            response = self.client.get_object(bucket_name=bucket, object_name=object_name)
            data = response.read()
            response.close()
            response.release_conn()
            logger.info("Downloaded %s from bucket %s (%d bytes)", object_name, bucket, len(data))
            return data
        except S3Error:
            logger.exception("Failed to download %s from %s", object_name, bucket)
            raise

    def get_presigned_url(
        self,
        bucket: str,
        object_name: str,
        expires: int = 3600,
    ) -> str:
        try:
            url = self.client.presigned_get_object(
                bucket_name=bucket,
                object_name=object_name,
                expires=timedelta(seconds=expires),
            )
            return url
        except S3Error:
            logger.exception("Failed to generate presigned URL for %s/%s", bucket, object_name)
            raise

    def delete_file(self, bucket: str, object_name: str) -> None:
        try:
            self.client.remove_object(bucket_name=bucket, object_name=object_name)
            logger.info("Deleted %s from bucket %s", object_name, bucket)
        except S3Error:
            logger.exception("Failed to delete %s from %s", object_name, bucket)
            raise
