# MXA OCR - Maintenance Guide

## Daily Tasks

- Monitor service health
- Check disk space
- Review error logs

## Weekly Tasks

- Review job statistics
- Check queue depth
- Analyze slow queries

## Monthly Tasks

- Database vacuum
- Update packages
- Review security logs
- Clean old files

## Backup Procedures

### Database Backup
```bash
pg_dump -U mxa_ocr_user mxa_ocr > backup_$(date +%Y%m%d).sql
```

### MinIO Backup
```bash
mc mirror myminio/mxa-ocr-input /backup/minio/input/
mc mirror myminio/mxa-ocr-output /backup/minio/output/
```

## Service Management

### Restart Services
```bash
sudo systemctl restart mxa-ocr-api
sudo systemctl restart mxa-ocr-worker
sudo systemctl reload apache2
```

### View Logs
```bash
sudo journalctl -u mxa-ocr-api -f
sudo journalctl -u mxa-ocr-worker -f
```

## Performance Monitoring

- CPU usage
- Memory usage
- Disk usage
- Queue depth
- Processing times
- Error rates

## Related Documentation
- [Troubleshooting](troubleshooting.md)
- [Deployment](deployment.md)
