# Cute boi — một chiếc ping

Website trong `nho-em/dist/`. Xem [hướng dẫn website](nho-em/README.md).

## Docker CI/CD lên VPS

Đầu `.github/workflows/deploy.yml` có cấu hình dễ sửa:

```yaml
env:
  CONTAINER_NAME: cute-boi
  APP_PORT: "3015"
```

Push lên `main` hoặc chạy **Actions → Check and deploy website → Run workflow** trên `main`: kiểm tra website, tải Docker build context lên VPS qua SSH, build image Nginx, kiểm tra container thử rồi thay container chính. Truy cập **http://IP_VPS:3015**. PR chỉ chạy kiểm tra.

### GitHub Actions Secrets

| Secret | Giá trị |
| --- | --- |
| `VPS_HOST` | IP hoặc hostname VPS, không có `https://` |
| `VPS_PRIVATE_KEY` | Toàn bộ SSH private key không có passphrase |
| `VPS_USER` | User SSH; mặc định `deploy` |
| `VPS_PORT` | Port SSH; mặc định `22` |

Tuỳ chọn: **Variable** `VPS_DEPLOY_PATH`, mặc định `/var/www/cute-boi`, là nơi chứa build context từng release.

SSH tự chấp nhận host key lần đầu mỗi workflow run (`accept-new`), không đối chiếu danh tính VPS từ trước. Các kết nối tiếp trong cùng run từ chối key thay đổi.

### Chuẩn bị VPS

Cần Linux với Bash, tar, curl và Docker Engine đang chạy. User SSH phải có public key tương ứng trong `~/.ssh/authorized_keys`, được ghi thư mục deploy và chạy Docker không cần sudo:

```bash
# Thay deploy bằng VPS_USER nếu khác.
sudo usermod -aG docker deploy
sudo install -d -m 755 -o deploy -g deploy /var/www/cute-boi/releases
```

Đăng nhập SSH lại sau khi thêm nhóm. Nhóm `docker` có quyền tương đương root, chỉ thêm user triển khai tin cậy. Cho phép TCP **3015** trên firewall VPS và security group của nhà cung cấp.

Không cần cài Nginx trực tiếp trên VPS cho cấu hình này: `deploy/nginx.conf` được copy vào image. Nginx cũ ở port 80 có thể vẫn chạy; website Docker nằm ở port 3015. Nếu cần domain/HTTPS, cấu hình reverse proxy riêng tới `localhost:3015`.

### Kiểm tra trên VPS

```bash
docker ps --filter name=cute-boi
docker logs --tail 50 cute-boi
curl -I http://localhost:3015
```

Container dùng `--restart unless-stopped`. Mỗi release có image riêng. Nếu image mới hoặc health check thất bại trước chuyển đổi, container cũ tiếp tục chạy. Nếu thay container thất bại, script khôi phục container cũ; có gián đoạn ngắn lúc chuyển đổi. Build context và image cũ được giữ lại để kiểm tra, cần dọn định kỳ.

### Chạy Docker tại máy

```bash
docker build -t cute-boi-site .
docker run -d --name cute-boi --restart unless-stopped -p 3015:80 cute-boi-site
```

Pipeline tải cả hai ảnh trong `nho-em/dist/` lên VPS. Chỉ triển khai khi bạn đã sẵn sàng chia sẻ nội dung website.
