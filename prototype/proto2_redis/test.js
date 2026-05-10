import http from 'k6/http';
import { check } from 'k6';

export let options = { vus: 100, duration: '10s' };

export default function () {
    // Đổi 'no-cache' thành 'with-cache' để xem Redis gánh tải
    let res = http.get('http://localhost:8012/manga/1/with-cache');
    check(res, { 'status was 200': (r) => r.status == 200 });
}