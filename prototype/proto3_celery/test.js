import http from 'k6/http';
import { check } from 'k6';

export let options = { vus: 10, duration: '10s' };

export default function () {
    // Đổi 'upload-sync' thành 'upload-async' để thấy API không bị treo
    let res = http.post('http://localhost:8013/upload-async');
    check(res, { 'status was 200': (r) => r.status == 200 });
}