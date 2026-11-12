# Cute boi — một chiếc ping

Website tĩnh trong `nho-em/dist/`. Xem [hướng dẫn website](nho-em/README.md).

## CI/CD lên VPS

Workflow `.github/workflows/deploy.yml` kiểm tra tài nguyên HTML, ID trùng, cú pháp JavaScript và script deploy. Pull request vào `main` chỉ chạy kiểm tra. Push lên `main` hoặc **Actions → Check and deploy website → Run workflow** trên `main` sẽ kiểm tra rồi triển khai.

### GitHub Actions Secrets

Vào **Settings → Secrets and variables → Actions → Secrets**:

| Secret | Giá trị |
| --- | --- |
| `VPS_HOST` | IP hoặc hostname VPS, không có `https://` |
| `VPS_PRIVATE_KEY` | Toàn bộ SSH private key, gồm dòng BEGIN/END; dùng key deploy không có passphrase |
| `VPS_USER` | User SSH, mặc định `deploy` nếu để trống |
| `VPS_PORT` | Port SSH, mặc định `22` nếu để trống |

Không cần `VPS_KNOWN_HOSTS`. Script dùng `StrictHostKeyChecking=accept-new`: tự chấp nhận host key ở kết nối đầu mỗi lần chạy và từ chối nếu key đổi trong cùng lần deploy. Key không được đối chiếu trước hoặc lưu giữa các workflow run.

Tuỳ chọn: đặt **Variable** `VPS_DEPLOY_PATH` nếu muốn đổi thư mục mặc định `/var/www/cute-boi`.

### Chuẩn bị VPS một lần (Ubuntu/Debian + Nginx)

```bash
sudo apt-get update
sudo apt-get install -y nginx
sudo adduser --disabled-password --gecos '' deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
sudo nano /home/deploy/.ssh/authorized_keys
# Dán PUBLIC KEY tương ứng với VPS_PRIVATE_KEY, mỗi key một dòng.
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo install -d -m 755 -o deploy -g deploy /var/www/cute-boi/releases
```

Cho phép SSH (mặc định port 22) và HTTP (port 80) trong firewall VPS. User deploy không cần sudo khi pipeline chạy.

Copy nội dung `deploy/nginx.conf` vào `/etc/nginx/sites-available/cute-boi`, sửa `server_name` nếu có domain. Nếu đổi `VPS_DEPLOY_PATH`, đổi cả `root` trong Nginx.

```bash
sudo ln -s /etc/nginx/sites-available/cute-boi /etc/nginx/sites-enabled/cute-boi
# Chỉ tắt site mặc định nếu đây là VPS dành cho website này:
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Sau deployment đầu tiên, mở `http://YOUR_VPS_HOST` hoặc domain đã cấu hình. HTTPS cần cấu hình chứng chỉ riêng cho domain. Nginx không cần reload ở các lần deploy tiếp theo.

Mỗi lần deploy tạo một thư mục release và chuyển symlink `current` sau khi tải xong. Các bản cũ được giữ lại, cần dọn định kỳ. Rollback trên VPS bằng cách chọn release cũ:

```bash
ls /var/www/cute-boi/releases
ln -s /var/www/cute-boi/releases/RELEASE_CU /var/www/cute-boi/rollback
mv -Tf /var/www/cute-boi/rollback /var/www/cute-boi/current
```

Pipeline chuyển toàn bộ `nho-em/dist/` lên VPS, bao gồm hai ảnh. Chỉ đẩy commit lên GitHub khi đã sẵn sàng triển khai.
