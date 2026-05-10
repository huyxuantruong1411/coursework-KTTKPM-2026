import http from 'k6/http';
import { check } from 'k6';

export let options = { vus: 50, duration: '10s' };

export default function () {
    // Để thấy sự khác biệt, bạn đổi 'image-direct' thành 'image-presigned'
    let res = http.get('http://localhost:8011/api/v1/image-presigned');
    check(res, { 'status was 200': (r) => r.status == 200 });
}