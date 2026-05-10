_Tài liệu Kiến trúc phần mềm/ Software Architecture Document_

_Phiên bản: 1.0_

**Tên dự án:** Xây dựng Web – App Quản lý Dịch vụ đọc Truyện tranh Online (Manga)

**Nhóm thực hiện:** Nhóm 17

**Ngày phát hành:** 23/03/2026

**Lịch sử sửa đổi (Revision History)**

<div class="joplin-table-wrapper"><table><tbody><tr><td><p><strong>Ngày tháng/ Date</strong></p></td><td><p><strong>Phiên bản/ Version</strong></p></td><td><p><strong>Mô tả/ Description</strong></p></td><td><p><strong>Các tác giả/Authors</strong></p></td></tr><tr><td><p>12/01/2026</p></td><td><p>0.1</p></td><td><h2>Xác định các bên liên quan</h2><ul><li>Xác định yêu cầu cho tất cả chức năng mà hệ thống có thể có</li></ul></td><td><p>Nhóm 17</p></td></tr><tr><td><p>02/03/2026</p></td><td><p>0.2</p></td><td><ul><li>Tên của mẫu kiến trúc chính được chọn, gồm các mẫu kiến trúc hỗ trợ, bổ sung cho hệ thống.</li><li>Vẽ biểu đồ mô tả trực quan các kiến trúc đó dưới dạng hình khối.</li><li>Liệt kê đầy đủ tên các thành phần (component) trong mỗi kiến trúc đó. Mô tả rõ chức năng của mỗi thành phần (component) của mỗi kiến trúc.</li><li>Gọi tên các công nghệ được chọn (nếu có, bao gồm phần cứng và phần mềm) để sử dụng trong các thành phần trong mỗi kiến trúc.</li></ul></td><td><p>Nhóm 17</p></td></tr><tr><td><p>09/03/2026</p></td><td><p>0.3</p></td><td><ul><li>Thiết kế View kiến trúc Logic (Logical Views)</li><li>Thiết kế View kiến trúc Cài đặt (Implementation Views)</li><li>Thiết kế View kiến trúc Tiến trình (Process Views)</li><li>Thiết kế View kiến trúc triển khai/Vật lý (Deployment Views)</li></ul></td><td><p>Nhóm 17</p></td></tr><tr><td><p>18/03/2026</p></td><td><p>0.4</p></td><td><p>Xác thực kiến trúc (Validation)</p></td><td><p>Nhóm 17</p></td></tr><tr><td><p>23/03/2026</p></td><td><p>1.0</p></td><td><p>Tổng hợp, hoàn thiện và đóng gói tài liệu SAD cuối cùng.</p></td><td><p>Nhóm 17</p></td></tr></tbody></table></div>

**Tên dự án/ Project name:** _Xây dựng Web – App Quản lý Dịch vụ đọc Truyện tranh Online_

1.  **Ngữ cảnh dự án/ Project context:**

- _Nêu tình trạng tổ chức/ doanh nghiệp:_ Hiện nay, cộng đồng đọc truyện tranh (Manga/Manhwa/Comic) tại Việt Nam và quốc tế rất lớn. Tuy nhiên, các hệ thống website đọc truyện hiện tại (hệ thống cũ hoặc của các bên đối thủ) đang gặp phải nhiều vấn đề nhức nhối:
- Hiệu năng kém và gián đoạn dịch vụ: Máy chủ thường xuyên bị quá tải (Crash/Downtime) khi có một bộ truyện hot ra chapter mới. Tốc độ tải ảnh chậm, gây ức chế cho người dùng.
- Quản lý dữ liệu phân tán thủ công: Quá trình thu thập (crawl) truyện từ các nguồn khác (Mangadex, Bato...) thiếu tự động hóa, dễ bị lỗi format dữ liệu, dẫn đến rác dữ liệu trong Database.
- Thiếu kiểm duyệt nội dung: Hình ảnh nhạy cảm (NSFW), bạo lực hoặc bình luận mang tính chất toxic/spoiler không được kiểm soát tốt do dùng sức người.
- Trải nghiệm người dùng nghèo nàn: Chưa có hệ thống gợi ý truyện thông minh (Recommend system) được cá nhân hóa; thiếu các tính năng tương tác thời gian thực (Real-time chat).
- _Nêu dự án này ra đời để đáp kỳ vọng gì của tổ chức/ doanh nghiệp: C_ung cấp một nền tảng đọc truyện thế hệ mới, giải quyết triệt để các bài toán về hiệu suất và tự động hóa. Dự án đáp ứng các kỳ vọng:
- Trải nghiệm mượt mà: Tốc độ tải trang dưới 2 giây, hỗ trợ đọc offline, lật trang/cuộn dọc không độ trễ.
- Khả năng mở rộng (Scalability): Chịu tải hàng chục ngàn Concurrent Users trong giờ cao điểm mà không sập hệ thống.
- Tự động hóa vận hành: Tích hợp AI để tự động kiểm duyệt ảnh (Swin Transformer), nhận diện chữ (OCR) hỗ trợ dịch thuật, và sử dụng ETL Pipeline tự động crawl/chuẩn hóa dữ liệu.
- Tương tác thời gian thực: Trở thành một mạng xã hội thu nhỏ cho giới yêu truyện với tính năng chat, thông báo đẩy tức thì khi có chương mới.

1.  **Những yêu cầu kiến trúc/ Architechture Requirements**

**2.1. Những mục tiêu chính của dự án**

- Xây dựng nền tảng (Web/App) cho phép người dùng đọc truyện, tương tác và tải truyện ngoại tuyến.
- Xây dựng hệ thống Backend mạnh mẽ với kiến trúc Microservices để dễ dàng bảo trì, mở rộng và tích hợp AI.
- Tối ưu hóa chi phí lưu trữ ảnh thông qua Object Storage (MinIO).

**2.2. Những yêu cầu về chức năng của các bên liên quan**

**1\. Đối với Độc giả:**

- Tìm kiếm & Trải nghiệm đọc: Tìm kiếm/lọc truyện theo thể loại, tác giả, đánh giá, ngôn ngữ. Hỗ trợ chế độ đọc linh hoạt (cuộn dọc, lật trang, zoom panel cho ảnh màu/đen trắng) và dịch tự động text trực tiếp trên trang truyện.
- Quản lý cá nhân: Tạo, quản lý (CRUD) danh sách đọc truyện cá nhân (Public/Private); theo dõi (Follow/Unfollow) danh sách của user khác. Cung cấp công cụ tìm kiếm lịch sử đọc theo khoảng thời gian/metadata.
- Tương tác & Cộng đồng: Thêm/sửa/xóa, like/dislike và báo cáo bình luận; đánh giá điểm số. Tích hợp tính năng Chat real-time với các người dùng (và Admin) trong hệ thống.
- Cập nhật & Ngoại tuyến: Bookmark, theo dõi updates, nhận thông báo Push khi có chapter mới và cho phép tải chapter về đọc ngoại tuyến.
- Gợi ý truyện (Recommend): Hệ thống tự động gợi ý truyện cá nhân hóa dựa trên lịch sử đọc và gợi ý các bộ truyện tương tự với bộ đang xem.

**2\. Đối với Người Upload bản dịch (Uploaders):**

- Quản lý đăng tải: Cung cấp công cụ upload batch bản dịch các chapter với các định dạng (JPEG, PNG, WebP) một cách dễ dàng.
- Quản lý danh sách: Quản lý danh sách các bản dịch đã đăng tải và hiển thị thông tin public của uploader để độc giả có thể theo dõi.

**3\. Đối với Quản trị viên:**

- Quản lý User & Content: Dashboard theo dõi xu hướng/lịch sử của user, thực hiện block/unblock tài khoản hoặc block những user đăng nội dung vi phạm. Quản lý, duyệt hoặc xóa các chapter vi phạm bản quyền/chuẩn mực. Xử lý các comment bị báo cáo.
- Vận hành hệ thống: Quản lý toàn bộ danh sách truyện trong hệ thống, bao gồm tuỳ chọn duyệt/cập nhật trực tiếp từ API bên thứ 3 (Mangadex, Bato...). Xem Dashboard báo cáo Analytics (Traffic, User growth, Popularity).

**4\. Đối với Developers / Maintainers:**

- Bảo trì & Mở rộng: Cung cấp RESTful API cho bên thứ 3 (Mobile App) tích hợp. Quản lý cấu hình CI/CD và giám sát hệ thống.
- AI Training: Cung cấp công cụ/luồng hỗ trợ định kỳ train lại tất cả các mô hình AI trong hệ thống dựa trên tập dữ liệu mới.

**5\. Đối với Data Source bên thứ 3 (Hệ thống ETL):** Tự động crawl và thực hiện ETLdữ liệu chapter truyện và thông tin Metadata từ Mangadex API hoặc cào thủ công từ bato, truyenqq...

**2.3. Những yêu cầu về chất lượng (phi chức năng) của các bên liên quan**

**1\. Ràng buộc về Hiệu suất:**

- Tốc độ phản hồi: Thời gian tải trang hiển thị phải dưới 2 giây. Các truy xuất biểu đồ analytics phức tạp phải hoàn thành dưới 15 giây (yêu cầu tích hợp ELK Stack để tối ưu truy vấn logs/dữ liệu).
- Xử lý tài nguyên tĩnh: Ảnh trong chapter phải được load bất đồng bộ (Lazy-load/Asynchronous) để đảm bảo không gián đoạn thao tác đọc các ảnh kích thước lớn. Quá trình xử lý dịch text bằng AI phải trả về kết quả dưới 15 giây/ảnh.

**2\. Khả năng mở rộng và Chịu tải:**

- Backend phải chịu tải được hàng nghìn request cùng lúc, bắt buộc sử dụng Apache Kafka + Redis; ưu tiên khả năng mở rộng theo chiều ngang (Horizontal Scaling).
- Dữ liệu hình ảnh và phi cấu trúc phải được lưu trữ trên Object Storage giống S3 (S3-like storage: MinIO (trong quá trình development vì miễn phí) hoặc AWS S3 (trên production nếu có dư tiền, không thì lại quay về dùng MinIO tiếp)) để giảm tải băng thông cho server chính. Dữ liệu đọc offline được cache qua một DB trung gian (Redis) hoặc load trực tiếp từ MinIO Data lake.

**3\. Độ tin cậy và Tính sẵn dùng:**

- Rollback tự động: Chức năng tự động cập nhật truyện toàn hệ thống (qua Mangadex API) phải có cơ chế tự động Rollback lại toàn bộ dữ liệu sạch trước đó nếu server bị down giữa chừng.
- Backup: Hệ thống tự động lập lịch backup toàn bộ DB đẩy lên Cloud (AWS S3 nếu đến lúc đó còn đủ tiền trả cho dịch vụ, không thì dùng tạm GG Big Query) mà không cần sự can thiệp thủ công.

**4\. Ràng buộc về Bảo mật (Security & Privacy):**

- Thiết kế RESTful API với chuẩn Auth (OAuth/JWT). Hệ thống có cơ chế tự động Block hoặc tạm thời giới hạn (Rate Limiting) truy cập từ các IP spam bất thường/DDoS.
- User bị Block sẽ bị cưỡng chế đăng xuất khỏi hệ thống ngay lập tức.
- Dữ liệu lịch sử đọc cá nhân có thể được cấp quyền (Toggle) hiển thị/ẩn với người dùng khác. Bình luận có bộ lọc từ cấm tự động và tính năng toggle ẩn/hiện văn bản chứa Spoiler.

**5\. Ràng buộc Kiến trúc Công nghệ & AI (Technical & AI Constraints):**

- Cấu trúc Database: Bắt buộc sử dụng UUID v4 làm khóa chính cho mọi bảng trong CSDL để dễ dàng đồng bộ định dạng với dữ liệu cào từ Mangadex API.
- AI Kiểm duyệt: Sử dụng mô hình Swin Transformer v2 quét ảnh NSFW. Yêu cầu thời gian quét tối đa < 5 phút cho mỗi chương. Vi phạm sẽ tự đẩy ticket cho Admin.
- AI Dịch thuật: Kết hợp OCR Scan và Google AI Mode (qua thư viện Playwright nếu cần), trong quá trình dev thì dùng tạm Google Translate API, nếu thấy ổn thì khỏi xài Google AI Mode.
- AI Gợi ý: Thuật toán gợi ý cá nhân hóa dựa trên query tĩnh (lấy max 20 truyện rating cao chứa 5 tags xem gần nhất). Thuật toán gợi ý truyện tương tự dùng BERTopic để phân cụm các comment/review đã được tiền xử lý (lọc nhiễu). Model AI cần được train định kỳ 6 tháng 1 lần.
- ETL Pipeline & Automation: Chạy Job lập lịch thu thập metadata vào _"Tối chủ nhật đầu tiên của quý"_ và nội dung chapter vào _"Tối thứ 2 đầu tiên của quý"_. Áp dụng cơ chế Full Load cho quý đầu tiên và Incremental Load cho các chu kỳ sau. Push notification (Kafka/WebSocket) phải alert thời gian thực khi có update.
- Nghiệp vụ độ trễ: Admin phải đợi 5 phút giữa 2 lần thao tác Block/Unblock trên cùng một user. Báo cáo comment bị Admin ignore sẽ có thời gian chờ 24 tiếng trước khi người dùng có thể report lại comment đó.

1.  **Trình bày kiến trúc**

**3.1. Các mẫu kiến trúc được sử dụng trong dự án**

1.  **Kiến trúc chính: Microservices Architecture Pattern**

Lý do: Mỗi dịch vụ xử lý một nghiệp vụ nhỏ và sở hữu Database (hoặc bảng/schema) riêng lẻ. Đảm bảo một service lỗi không làm sập các tính năng khác.

1.  **Kiến trúc hỗ trợ 1: Client – Server Architecture Pattern**

Lý do: Trình duyệt web (Client) sẽ đóng vai trò thiết lập giao diện và trực tiếp gửi request (HTTP/REST) tới các cụm máy chủ Microservices (Server) để xin cấp phát tài nguyên (ảnh, text).

1.  **Kiến trúc hỗ trợ 2: Broker Architecture Pattern**

Lý do: Giải quyết bài toán giao tiếp giữa hàng chục service nhỏ. Sử dụng Broker để điều phối các sự kiện.

1.  **Kiến trúc hỗ trợ 3: Pipe-Filter Architecture Pattern**

Lý do: Xử lý một chuỗi transformation dữ liệu từ nơi này sang nơi khác để lưu và dùng.

**3.2. Kiến trúc tổng quan của dự án**

- Nhóm Identity (Tài khoản & Phân quyền):
- Registration Svc & Login Svc: Quản lý tạo tài khoản mới và cấp phát JWT.
- User Profile Svc: CRUD avatar, tên hiển thị, bio.
- User Sanction Svc: Lưu trữ trạng thái Block/Unblock, quản lý bộ đếm lùi 5 phút cấm thao tác, kick session.
- Role Mngt Svc: Xác định ai là Admin, ai là Uploader.
- Reading Preferences Svc: Lưu cấu hình đọc ví dụ "chế độ zoom panel" của độc giả.
- Nhóm Catalog (Thông tin truyện tĩnh):
- Manga Info Svc: CRUD thông tin cơ bản: Tên, tóm tắt.
- Author & Studio Svc / Taxonomy Svc: Chuẩn hóa tên tác giả và hệ thống Tag, Ngôn ngữ (Anh/Việt).
- Manga Search Svc & Manga Filter Svc: Chuyên trị query tìm kiếm text và lọc theo điều kiện phức tạp.
- Nhóm Reader & Media (Truyền tải ảnh & Upload):
- Chapter Metadata Svc: Lưu thông tin chap mấy, thuộc volume nào, tên chapter.
- Page Ordering Svc: Quản lý số thứ tự các trang ảnh trong một chapter để UI render không bị lộn xộn.
- Batch Upload Svc: Mở port cho uploader đẩy file hàng loạt lên RAM máy chủ.
- Image Validation Svc: Check MIME type (JPEG, PNG, WebP) và dung lượng file.
- Presigned URL Generator Svc: Sinh ra các link tạm thời từ kho ảnh MinIO cho UI load trực tiếp (không qua server Backend).
- Offline Package Builder Svc: Đóng gói các ảnh của chapter thành file nén trả về cho UI.
- Nhóm Interaction & Chat (Tương tác xã hội):
- Comment Write Svc & Comment Read Svc: Tách biệt luồng ghi và luồng đọc comment.
- Spoiler Management Svc: Xử lý cờ (flag) ẩn/hiện comment spoil nội dung truyện.
- Profanity Check Svc: Lọc từ cấm trước khi đẩy comment vào DB.
- Rating Calculation Svc & Report Ticket Svc: Tính trung bình sao; Quản lý ticket báo cáo, quản lý timer chờ 24h nếu bị ignore.
- Chat Svc (WS, Room, Message): Mở luồng WebSocket, phân luồng phòng chat, lưu tin nhắn real-time giữa users.
- Nhóm Library (Thư viện cá nhân của người dùng):
- Reading Coordinate Svc: Liên tục ghi nhận (Append-only) người dùng đang đọc tới trang nào, hình nào (Yêu cầu 12).
- List Builder Svc & List Privacy Svc: Tạo các danh sách Manga tùy chỉnh, cấu hình Private/Public.
- Follow Manga Svc & Follow List Svc: Ghi nhận đăng ký theo dõi truyện hoặc list người khác.

Công nghệ sử dụng:

- Framework: FastAPI.
- ORM: SQLAlchemy.
- WebSockets: Sử dụng FastAPI WebSockets module.

Web Browser Client Component: Render giao diện. Xử lý logic tải ảnh bất đồng bộ, xử lý chế độ đọc lật trang/cuộn dọc, lưu trữ file ảnh zip ngoại tuyến vào IndexedDB/Local storage trình duyệt.

Công nghệ sử dụng: Next.js (React framework), giao tiếp qua Fetch API và WebSocket.

Apache Kafka Broker giao tiếp sự kiện. Khi Follow Manga Svc ghi nhận user bấm theo dõi, hoặc Batch Upload Svc báo nhận ảnh xong 🡪 Tạo sự kiện đẩy vào Kafka.

Công nghệ sử dụng: Apache Kafka: Xử lý chịu tải message. Dùng thư viện aiokafka để kết nối từ FastAPI.

- Intake Filter: Nhận data thô từ luồng Crawl (Mangadex) hoặc Upload.
- OCR Filter / Translator Filter: Quét chữ trên ảnh (Tesseract) 🡪 Gọi Playwright dịch.
- Swin NSFW Filter: Quét ảnh khỏa thân/bạo lực. Trả kết quả pass/fail.
- Notification Worker: Lắng nghe Kafka, phân phát Alert thời gian thực.
- Personalized & BERTopic Worker: Tính toán offline danh sách truyện gợi ý dựa trên Lịch sử & Text.

Công nghệ sử dụng:

- Task Queue: Celery chạy cùng Redis broker.
- AI (Hình ảnh & NLP): PyTorch (cho mô hình Swin Transformer v2), BERTopic.
- ETL & Dịch thuật: BeautifulSoup4 (Cào text), Playwright (Cào tự động Google Translate, GG AI Mode), Tesseract OCR (Trích xuất chữ từ ảnh).
- DBT

- PostgreSQL Master: Nút cơ sở dữ liệu xử lý 100% các request Write (Tạo user, comment, bookmark...). Khóa chính dùng UUID v4.
- PostgreSQL Slaves: Bản sao đồng bộ từ Master. Mọi Microservices khi cần thực hiện lệnh SELECT (như load chương, tìm truyện) đều query vào Slaves.
- Mangadex Rollback Worker: Lắng nghe Kafka, nếu cào bị lỗi sẽ rollback toàn bộ ID đã lưu.
- Traffic Analytics & System Backup Worker: Xử lý vẽ biểu đồ (<15s), xuất Excel, dump DB đẩy lên S3 tự động.

Công nghệ sử dụng:

- PostgreSQL: Quản lý Master-Slave native replication.
- Redis: Phân tán cache, lưu session chat.
- MinIO: Object Storage lưu trữ ảnh tĩnh chuẩn S3.

**3.3. Thiết kế View kiến trúc Logic (Logical Views)**

**Biểu đồ usecase tổng thể**

Giải thích các Use case tổng thể:

- Đăng ký/Đăng nhập: Quản lý định danh, cấp phát token JWT, xác thực quyền hạn.
- Tìm kiếm & Lọc truyện: Truy vấn danh sách truyện theo thể loại, tác giả, trạng thái, (tối ưu hóa trên các Slave Database).
- Đọc truyện & Tải Offline: Tải metadata của chương, nhận Presigned URL từ MinIO để lấy ảnh trực tiếp, đóng gói ảnh tải ngoại tuyến thành file .zip gửi cho độc giả.
- Bình luận & Tham gia Chat: Đăng bình luận, đánh dấu spoiler, và duy trì luồng giao tiếp thời gian thực qua WebSocket.
- Lưu Bookmark & Tọa độ đọc: Đánh dấu truyện yêu thích và tự động ghi nhận vị trí trang đang xem.
- Đăng tải chương truyện (Batch): Cho phép Uploader đẩy hàng loạt hình ảnh lên server thông qua luồng upload tối ưu.
- Kiểm duyệt AI (NSFW/OCR): Hệ thống ngầm tự động quét ảnh nhạy cảm và nhận diện ký tự để dịch thuật hoặc tìm kiếm text trên ảnh.
- Quản lý Cấu hình & User: Phân quyền hệ thống, khóa tài khoản vi phạm, cấu hình banner.

**Biểu đồ lớp tổng thể**

- Package Identity Domain: Chứa các lớp User, Role, Session. Chịu trách nhiệm quản lý thông tin định danh, phân quyền và vòng đời của chuỗi mã hóa JWT.
- Package Catalog Domain: Chứa các lớp Manga, Author, Tag, Chapter. Đây là core của dịch vụ tra cứu, các bộ truyện được gắn tag và liên kết với danh sách các chương.
- Package Media & Library Domain: Chứa các lớp Page và ReadingCoordinate. Lớp Page đảm nhận ánh xạ file vật lý trên MinIO thành các Presigned URL, trong khi ReadingCoordinate lưu vết lịch sử đọc của từng độc giả.
- Package Interaction Domain: Chứa các lớp Comment, ReportTicket. Quản lý dữ liệu tương tác, che nội dung spoiler và xử lý các báo cáo vi phạm.
- Package AI Worker Domain: Chứa lớp AIModelEvaluator. Quản lý các dữ liệu đo lường chất lượng của các mô hình học máy (như mô hình gợi ý, nhận diện ảnh). Bổ sung thêm các metric để kiểm tra mô hình bên cạnh những metric cũ (F1 score, ...) ví dụ như R^2 và các metric liên quan nhằm đảm bảo độ tin cậy của AI.

**3.4. Thiết kế View kiến trúc Cài đặt (Implementation Views)**

**Biểu đồ gói**

- \[Next.js UI Pages\]: Gói mã nguồn chứa các file giao diện (.tsx/.jsx), chịu trách nhiệm hiển thị HTML tĩnh và định tuyến phía trình duyệt.
- \[React Hooks & State\]: Gói chứa các hàm logic frontend để quản lý trạng thái tải trang, dữ liệu tạm thời và bộ nhớ đệm.
- \[Nginx / Kong Routing\]: Gói cấu hình file (.conf), quy định các luật định tuyến, chặn DDoS và giới hạn băng thông cho toàn hệ thống.
- \[Identity Service\]: Mã nguồn Python (FastAPI) chuyên biệt cho việc mã hóa mật khẩu, tạo token và kiểm tra quyền truy cập.
- \[Catalog Service\]: Mã nguồn Python xử lý truy vấn tìm kiếm phức tạp, bộ lọc truyện và chuẩn hóa dữ liệu từ database.
- \[Interaction Service\]: Mã nguồn Python quản lý luồng dữ liệu WebSocket cho tính năng chat thời gian thực và ghi nhận bình luận.
- \[Media Upload Service\]: Gói mã nguồn mở cổng tiếp nhận file, kiểm tra MIME type, giải nén file zip ảnh tải lên từ Uploader.
- \[Offline Package Builder\]: Gói mã nguồn đóng gói hàng loạt file ảnh thành các cục nén để Client tải về thiết bị đọc offline.
- \[Celery Task Dispatcher\]: Gói mã nguồn quản lý hàng đợi, phân phát các tác vụ tốn thời gian từ Kafka đến các node Worker nhàn rỗi.
- \[Swin NSFW Filter\]: Gói mã nguồn PyTorch chứa trọng số mô hình Swin Transformer, làm nhiệm vụ phân tích ma trận ảnh để phát hiện nội dung độc hại.
- \[OCR Processor\]: Gói mã nguồn tích hợp Tesseract để trích xuất văn bản từ khung thoại trong ảnh truyện tranh.

**Biểu đồ thành phần**

- Web Browser (React): Thành phần thực thi chạy trên máy người dùng cuối, đóng vai trò hiển thị giao diện và trực tiếp gọi các giao thức mạng.
- API Gateway: Thành phần container độc lập, lắng nghe tại cổng 80/443, phân giải URL để trỏ chính xác vào các Service backend bên trong mạng nội bộ.
- Identity API: Thành phần container chạy uvicorn server, sở hữu DB riêng. Xử lý các endpoint bắt đầu bằng /api/v1/auth.
- Catalog API: Thành phần container chịu tải chính cho việc đọc dữ liệu truyện. Xử lý các endpoint bắt đầu bằng /api/v1/manga.
- Chat API: Thành phần container duy trì hàng nghìn kết nối TCP mở (WebSocket) cho tính năng chat. Xử lý qua /ws/chat.
- Kafka Message Broker: Thành phần cụm máy chủ trung gian (Cluster) lưu trữ các thông điệp sự kiện vào các Topic phân tán, đảm bảo không mất mát dữ liệu khi hệ thống quá tải.
- AI Worker Node: Thành phần thực thi chạy ngầm (Daemon), liên tục pull tin nhắn từ Kafka để chạy các thuật toán AI nặng mà không phản hồi trực tiếp cho HTTP request.
- MinIO Storage Server: Thành phần máy chủ lưu trữ Object Storage, thay thế cho ổ cứng cục bộ để lưu trữ và phân phối file ảnh tĩnh (JPEG, PNG) với hiệu suất cao trực tiếp cho Client.

**3.5. Thiết kế View kiến trúc Tiến trình (Process Views)**

**Biểu đồ hoạt động (Activity diagram):**

Tiến trình Đọc truyện

Giải thích Tiến trình Đọc truyện: Tiến trình này tối ưu hóa việc truyền tải. Thay vì Backend phải đọc file ảnh và gửi về (gây nghẽn băng thông), Media Service chỉ tính toán và sinh ra các **Presigned URLs** (đường dẫn có chữ ký tạm thời). Client sử dụng các đường dẫn này để kéo ảnh trực tiếp từ máy chủ lưu trữ Object Storage. Song song đó, tiến trình đọc liên tục bắn tọa độ về hệ thống để lưu lại vị trí trang hiện tại.

**Tiến trình Upload & Xử lý AI ngầm**

Áp dụng mẫu kiến trúc Pipe-Filter và Background Jobs. Khi người dùng tải ảnh lên, Backend không bắt người dùng chờ AI xử lý xong. Nó chỉ lưu file tạm thời và báo thành công, sau đó ném sự kiện vào Kafka. Các tiến trình AI ngầm sẽ lấy ảnh từ MinIO xuống để chạy mô hình Swin NSFW (kiểm duyệt) và OCR (nhận diện chữ), sau đó tự động cập nhật trạng thái hiển thị của chương truyện.

**Tiến trình Chat Real-time**

Giải thích Tiến trình Chat Real-time: Sử dụng giao thức WebSocket kết hợp Redis Pub/Sub để duy trì kết nối luồng kép. Khi một tin nhắn được gửi, nó đi qua bộ lọc từ ngữ trước. Nếu an toàn, tin nhắn được lưu xuống DB và đẩy vào Redis Pub/Sub. Cơ chế Pub/Sub của Redis sẽ chịu trách nhiệm phát sóng (Broadcast) tin nhắn đó đến toàn bộ các Server FastAPI đang giữ kết nối WebSocket với các người dùng khác trong cùng phòng.

**Tiến trình Crawl & Đồng bộ dữ liệu ETL (Pipe-Filter)**

Giải thích: Hệ thống sử dụng một bộ lập lịch (Cronjob) để kích hoạt tự động. Thay vì lưu trực tiếp dữ liệu từ nguồn ngoài vào DB chính gây rủi ro toàn vẹn, luồng xử lý áp dụng ETL (Extract – Transform – Load). Dữ liệu JSON thô đi qua màng lọc (Intake Filter) đổ vào Staging DB, sau đó qua màng lọc chuẩn hóa và dịch thuật, cuối cùng mới được Service chịu trách nhiệm ghi vào DB Master.

**Tiến trình Cấp quyền và Xác thực (Identity Workflow)**

Giải thích: Mọi yêu cầu xác thực trước tiên phải đi qua API Gateway để đếm số lần thử (Rate Limiting), ngăn chặn tấn công dò mật khẩu. Tại \`Identity Service\`, sau khi xác minh Hash mật khẩu, hệ thống sinh ra JWT để Client mang theo trong các Request tiếp theo. Phiên đăng nhập được đẩy vào Redis Cache cho phép hệ thống thu hồi token ngay lập tức nếu phát hiện bất thường mà không cần truy vấn lại DB.

**3.6. Thiết kế View kiến trúc triển khai/Vật lý (Deployment Views)**

Giải thích các Thành phần Triển khai vật lý:

- Thiết bị Khách: Điện thoại hoặc PC chạy trình duyệt web tải ứng dụng React (SPA).
- Load Balancer Node: Máy chủ vật lý hoặc VM đứng mũi chịu sào (ví dụ Nginx), nhận mọi traffic từ Internet, cung cấp SSL và phân tán tải trọng mạng.
- Application Cluster: Cụm máy chủ chạy Docker Swarm (Nếu còn dư dả thời gian build thì chuyển qua xài K8S ngon hơn). Mỗi máy chủ sẽ host nhiều Container chứa các Microservices (FastAPI). Có khả năng scale tự động.
- AI GPU Nodes: Máy chủ chuyên dụng có trang bị Card đồ họa (GPU). Cài đặt môi trường CUDA để chạy mô hình AI PyTorch (Swin/OCR) qua Celery Worker.
- Message Broker Node: Cụm máy chủ chạy Apache Kafka. Đây là trục xương sống giao tiếp bất đồng bộ, chịu tải sự kiện.
- Object Storage Node: Cụm máy chủ lưu trữ ổ cứng dung lượng cao (HDD/SSD). Chạy MinIO phân tán, chịu trách nhiệm lưu trữ và phục vụ tải ảnh trực tiếp không cần thông qua Application Cluster.
- Database Cluster: Cụm máy chủ cơ sở dữ liệu áp dụng mẫu Master – Slave. Máy chủ Master hứng chịu toàn bộ lệnh Ghi (Write). Máy chủ Slave đồng bộ liên tục từ Master và xử lý 100% các lệnh Đọc (Read - VD: Tải danh sách truyện). Redis Cluster được tách riêng để xử lý truy xuất tức thời vào RAM.

**4\. Tài liệu xác thực kiến trúc**

Trước khi giả định, em cần nhấn mạnh lại một số kiến trúc hoặc công nghệ highlight của nhóm đã chọn lựa trước đó. Vì nhóm em chọn nó để giải quyết phần nào các tình huống thực tế có thể xảy ra (nên sẽ được trích dẫn lại rất nhiều trong phản hồi của bảng bên dưới):

- Microservices
- Event – Driven với Kafka
- Master – Slave Database
- Pipe – Filter cho AI/ETL
- Redis Cluster
- Minio

**4.1. Xác thực yêu cầu về Tính sẵn dùng (Availability)**

<div class="joplin-table-wrapper"><table><tbody><tr><td><p><strong>Thuộc tính chất lượng (Quality Attribute)</strong></p></td><td><p><strong>Sự cố giả định (Stimulus)</strong></p></td><td><p><strong>Phản hồi của hệ thống (Response)</strong></p></td></tr><tr><td><p><strong>1. Tính sẵn dùng (Availability)</strong></p><p><em>(Khả năng hệ thống duy trì hoạt động hoặc phục hồi nhanh khi có lỗi)</em></p></td><td><p><strong>Sự cố 1:</strong> Máy chủ chứa Catalog đột ngột bị sập do tràn RAM (Out of Memory).</p></td><td><p>Em đặt vấn đề không phải lỗi linh tinh thông thường mà là lỗi OOM vì nó rất khó chịu trên những container chạy Linux, đặc biệt là những người mới dùng Docker.</p><p></p><p>Cần giải thích một chút là lỗi OOM trên các hệ điều hành Linux (ở đây chứa Docker) sẽ kích hoạt cơ chế OOM Killer bắn chết hết các tiến trình của container đó ngay lập tức (Exit code 137). Một số dev mới hay có thói quen để mặc định check trạng thái “UNHEALTHY” của container bất kỳ trong một cụm rồi mới xử lý lỗi. Nhưng đằng này nó chuyển hẳn sang trạng thái “EXITED” luôn. Nếu chỉ dùng Docker thông thường thì phải cài thêm policy để nó còn biết tự khởi động lại Container nếu exit đột ngột.</p><p></p><p>Nhóm em lại không thích rườm rà như vậy nên chọn một giải pháp đơn giản mà hiệu quả hơn: Cụm Application Cluster được quản lý bởi công cụ điều phối Docker Swarm. Khi máy chủ Catalog API bị tràn RAM, rõ ràng lúc đó hệ điều hành sẽ kill sạch tiến trình, làm container bị ngắt đột ngột. Trình điều phối Swarm Manager sẽ lập tức phát hiện trạng thái thực tế bị thiếu hụt so với cấu hình (desired state: Ví dụ em khai báo lúc đầu là service này luôn phải có 3 replica chạy khỏe, nếu văng mất 1 2 cái thì sẽ tự động khởi tạo container mới trên node bất kỳ để đảm bảo đúng yêu cầu cấu hình). Nó sẽ ra lệnh tự động spin up một container thay thế, đồng thời Load Balancer tự động loại bỏ node chết khỏi danh sách định tuyến, chuyển traffic sang các node còn lại. Quá trình tự phục hồi diễn ra tự động mà người dùng gần như không cảm nhận được gián đoạn.</p></td></tr><tr><td><p></p></td><td><p><strong>Sự cố 2:</strong> Cụm Database Master (PostgreSQL) bị hỏng ổ cứng, ngừng hoạt động hoàn toàn.</p></td><td><p>Cần nhắc lại rằng “ghi” là của một mình ông DB Master xử lý, còn luồng đọc là do bọn DB Slave đảm nhận 100%. Trong sự cố này thì luồng ghi bị ảnh hưởng do DB Master chết đột ngột. Cũng cần lưu ý luồng ghi sẽ gồm 2 kiểu dữ liệu ứng với 2 thao tác:</p><ol><li>Với thao tác Ghi trực tiếp (Ví dụ: Đổi mật khẩu, Viết bình luận): Hệ thống API sẽ không kết nối được tới Master, sinh ra lỗi Connection Timeout. API Gateway có thể trả về cho Frontend mã lỗi 503 Service Unavailable hoặc hiển thị thông báo "Hệ thống đang bảo trì tính năng này, vui lòng thử lại sau".</li><li>Với thao tác Upload truyện (Nhờ Kafka gánh vác): Khi uploader đẩy ảnh lên, Media Upload Service nhận file, lưu vào MinIO và sinh ra một Event ném vào Apache Kafka. Lúc này dù Master DB có chết, tin nhắn vẫn nằm an toàn trong hàng đợi của Kafka. Khi DB được sửa xong, các AI Worker sẽ từ từ lấy tin nhắn ra và ghi vào DB. =&gt; Không mất mát dữ liệu.</li></ol><p>Do đó, nhờ áp dụng mẫu kiến trúc <strong>Master – Slave</strong>, toàn bộ các lệnh "Đọc" (người dùng xem danh sách truyện, đọc chương truyện) hiển nhiên vẫn diễn ra bình thường vì chúng được query từ Slave DB và Redis Cache. Các lệnh "Ghi" (đăng truyện, bình luận) sẽ tạm thời báo lỗi hoặc được đưa vào hàng đợi. Hệ thống không thể sống mãi mà không có Master. Quá trình khắc phục diễn ra như sau:</p><ol><li>Alerting: Các hệ thống giám sát (Prometheus/Grafana) hoặc Notification Worker liên tục ping DB Master. Khi rớt kết nối, nó bắn cảnh báo khẩn cấp (qua Telegram/Email) cho Quản trị viên (DevOps/DBA).</li><li>Promotion: Quản trị viên can thiệp (hoặc dùng tool tự động như Patroni). Họ gỡ bỏ chế độ Read – Only của một node Slave khỏe nhất, promote nó lên làm Master mới.</li><li>Reconfiguration: Cập nhật lại chuỗi kết nối (Connection String / DNS) để các Microservices trỏ IP Master mới về cái máy vừa được thăng cấp.</li><li>Khôi phục hoàn toàn: Tính năng "Ghi" hoạt động trở lại bình thường. Quản trị viên có thể mua ổ cứng mới, cài lại một Node mới và gán nó làm Slave bổ sung vào cụm sau.</li></ol></td></tr></tbody></table></div>

**4.2. Xác thực yêu cầu về Khả năng cập nhật (Modifiability)**

<div class="joplin-table-wrapper"><table><tbody><tr><td><p><strong>Thuộc tính chất lượng (Quality Attribute)</strong></p></td><td><p><strong>Sự cố giả định (Stimulus)</strong></p></td><td><p><strong>Phản hồi của hệ thống (Response)</strong></p></td></tr><tr><td rowspan="2"><p><strong>2. Khả năng cập nhật (Modifiability)</strong></p><p><em>(Khả năng thay đổi, nâng cấp tính năng mà không làm ảnh hưởng hệ thống cũ)</em></p></td><td><p><strong>Sự cố 1:</strong> Đội ngũ Data Science muốn thay thế mô hình AI Swin NSFW cũ bằng một mô hình mới nặng hơn, yêu cầu thư viện Pytorch phiên bản khác.</p></td><td><p>Thông thường nếu xài kiến trúc nguyên khối, việc nâng cấp PyTorch có thể gây xung đột thư viện (dependency) với các phần khác của backend (như thư viện xử lý ảnh, database driver). Khi đó toàn bộ hệ thống buộc phải restart lại, gây gián đoạn dịch vụ</p><p>Nhưng nhờ kiến trúc <strong>Pipe-Filter &amp; Workers</strong> và việc tách rời thông qua <strong>Kafka</strong>, mấy ông DS chỉ cần tạo một AI Worker Node mới chứa mô hình mới và deploy nó. Các service khác như Upload Service hay Catalog Service hoàn toàn không can hệ gì và cũng không cần sửa một dòng code nào, cũng không cần restart luôn. Ở đây mình có thể hình dung đơn giản như sau:</p><ul><li>Pipe: Là Kafka, làm nhiệm vụ vận chuyển dữ liệu (sự kiện ảnh cần kiểm duyệt) từ trạm này sang trạm khác.</li><li>Filter: Là các AI Worker (Swin NSFW Filter, OCR Processor). Mỗi Filter là một module độc lập, chỉ làm đúng một việc: Nhận dữ liệu đầu vào từ Pipe 🡪 Xử lý (chạy AI) 🡪 Đẩy kết quả ra một Pipe khác hoặc cập nhật vào Database.</li></ul><p>🡪 Việc thay đổi mô hình AI thực chất chỉ là việc tháo một Filter cũ ra khỏi đường ống và lắp một Filter mới vào, hoàn toàn không làm vỡ cấu trúc của toàn bộ quy trình kiến trúc được setup lúc đầu.</p></td></tr><tr><td><p><strong>Sự cố 2:</strong> Nền tảng muốn tích hợp thêm cổng thanh toán (Momo/ZaloPay) để độc giả mua chương truyện Premium.</p></td><td><p>Thông thường đối với kiến trúc nguyên khối cũ, nếu muốn cập nhật một chức năng mới cho một hệ thống đã hoàn thiện, cần sửa source code thêm mới module “Payment” vào, và sửa các bảng trong DB.</p><p>Nhưng nhờ kiến trúc <strong>Microservices</strong>, hệ thống của nhóm em cho phép tạo một Payment Service hoàn toàn mới, tích hợp các cổng thanh toán và độc lập với Database riêng. Quy trình triển khai thì y hệt như những service khác:</p><p>Đóng gói Payment Service thành một Docker Image và ra lệnh cho Docker Swarm chạy nó lên thành các Container mới (ví dụ: chạy 2 replicas). Lúc này, Payment Service đã chạy ngầm trong mạng nội bộ, nhưng người dùng bên ngoài chưa hề biết đến sự tồn tại của nó. Các service đọc truyện cũ vẫn hoạt động bình thường, không hề bị ảnh hưởng.</p><p>Quản trị viên lúc này chỉ cần thêm vài dòng cấu hình để định tuyến API Gateway cho phép người dùng trỏ tới Payment Service vừa tạo. App/Web Frontend của người dùng đã có thể gọi API thanh toán.</p><p>Cuối cùng là cấu hình các giao tiếp nội bộ với các service khác. Giả sử: Khi Momo gọi Webhook báo thanh toán thành công về Payment Service. Payment Service ghi nhận vào DB của nó, sau đó ném một sự kiện PREMIUM_UNLOCKED {user_id, chapter_id} vào Kafka Message Broker. Catalog Service (đang lắng nghe Kafka) nhận được tin nhắn này, cập nhật trạng thái quyền đọc của user đối với chapter đó trong Database Slave/Redis của riêng nó. Sự liên kết lỏng lẻo này giúp 2 service không gọi trực tiếp lẫn nhau, tránh việc một bên sập kéo theo bên kia sập.</p><p>Toàn bộ các quy trình trên có thể được thực hiện ngay trong lúc các service khác đang chạy mà không lo gián đoạn dịch vụ hay phải bảo trì hệ thống.</p></td></tr></tbody></table></div>

**4.3. Xác thực yêu cầu về Tính bảo mật (Security)**

|     |     |     |
| --- | --- | --- |
| **Thuộc tính chất lượng (Quality Attribute)** | **Sự cố giả định (Stimulus)** | **Phản hồi của hệ thống (Response)** |
| **3\. Tính bảo mật (Security)**<br><br>_(Khả năng ngăn chặn, chống lại các cuộc tấn công và truy cập trái phép)_ | **Sự cố 1:** Hacker sử dụng tool tự động gửi 10,000 request/giây vào endpoint Đăng nhập (/api/v1/auth) nhằm dò rỉ mật khẩu (Brute-force). | Nhóm em đã tính toán cho hai cơ chế bảo mật dưới đây:<br><br>Cơ chế Rate Limiting: API Gateway được cấu hình để đếm số lượng request đến từ một địa chỉ IP (hoặc một dải IP) trong một khung thời gian. Cấu hình chỉ cho phép tối đa 5 request đăng nhập / 1 phút / 1 IP. Khi tool của hacker gửi đến request thứ 6, API Gateway sẽ lập tức chặn đứng request này lại. Nó không thèm forward request đó vào mạng nội bộ (nơi chứa các Microservices), mà lập tức trả thẳng về cho hacker mã lỗi HTTP 429 Too Many Requests hoặc 403 Forbidden. Kết quả, Identity Service và cơ sở dữ liệu PostgreSQL ở bên trong hoàn toàn bình yên vô sự. CPU và RAM của hệ thống không bị lãng phí để xử lý 10,000 cái request rác kia, nhờ đó hệ thống không bị đánh sập (chống được luôn cả DDoS tầng Application).<br><br>Mặc khác, đối với các hacker chuyên nghiệp có thể dùng Mạng Botnet hoặc Proxy đổi IP liên tục để qua mặt API Gateway. Giả sử kịch bản tồi tệ nhất xảy ra: Hacker dò được một số mật khẩu yếu, hoặc hệ thống bị dính lỗi SQL Injection khiến toàn bộ Database bị tải trộm ra ngoài. Lúc này, lớp phòng thủ thứ hai tại Identity Service sẽ phát huy tác dụng: Hệ thống KHÔNG BAO GIỜ lưu mật khẩu dưới dạng văn bản thô (Plain-text) như 123456 hay password.<br><br>Trước khi lưu xuống Database, Identity Service đã sử dụng thuật toán băm (Hashing) một chiều cường độ cao (Bcrypt và Argon2) kết hợp với Salt (chuỗi ngẫu nhiên sinh ra cho từng user). Mật khẩu 123456 sẽ biến thành một chuỗi vô nghĩa như $2b$12$eImiTXuWVxfM37uY4JANj...<br><br>Về lý thuyết, thuật toán Hash được thiết kế bằng toán học sao cho: Từ mật khẩu suy ra chuỗi Hash thì rất dễ, nhưng từ chuỗi Hash không thể nào dịch ngược lại ra mật khẩu gốc. Kết quả, Hacker cầm trong tay toàn bộ Database cũng đành bó tay chịu chết. Chúng không thể biết mật khẩu thật của độc giả là gì để đi đăng nhập trái phép vào hệ thống, bảo vệ an toàn tuyệt đối cho tài sản số và thông tin cá nhân của người dùng. |
| **Sự cố 2:** Kẻ tấn công cố gắng đánh sập máy chủ bằng cách liên tục request tải các hình ảnh dung lượng cao của truyện tranh. | Cần lưu ý rằng, hệ thống của nhóm tách biệt độc lập backend với nơi lưu trữ ảnh. Do đó, hệ thống Backend sẽ không bị sập. Theo tiến trình đọc truyện (đã vẽ ở Bài 3), hệ thống chỉ trả về **Presigned URLs**. Request tải ảnh thực tế được đẩy thẳng sang **MinIO Object Storage Cluster**.<br><br>Khi hacker (hoặc độc giả) request xem một chương truyện (gọi vào Catalog API), Backend FastAPI tuyệt đối không đi tìm file ảnh để trả về. Thay vào đó, Backend chỉ query Database để lấy danh sách tên file, sau đó gọi thư viện mã hóa sinh ra các Presigned URLs (Đường dẫn có chữ ký giới hạn thời gian). Chuỗi JSON Backend trả về cực kỳ nhẹ (chỉ vài Kilobyte). Quá trình này tiêu tốn cực ít CPU và RAM của Backend.<br><br>Ở trình duyệt của hacker, sau khi nhận được mảng URL trên, sẽ sử dụng các URL đó để tải ảnh. Đáng chú ý, các URL này không trỏ về Backend FastAPI, mà trỏ thẳng đến MinIO Object Storage Cluster. MinIO được thiết kế (bằng ngôn ngữ Go) chuyên biệt tốt cho việc phân phối nội dung tĩnh. Nó có khả năng mở rộng hàng chục Node và sử dụng cơ chế truyền tải Zero-copy của hệ điều hành để đẩy dữ liệu qua mạng với tốc độ tối đa của card mạng vật lý, mà không tốn CPU tính toán.<br><br>Khi hacker tung hàng chục ngàn request tải ảnh, Application Cluster Hoàn toàn bình yên vô sự. CPU rảnh rỗi, RAM trống trơn. Các API đăng nhập, chat, tìm kiếm truyện vẫn hoạt động tốt. MinIO Cluster Hứng trọn lượng traffic khổng lồ này. Nếu traffic vượt quá ngưỡng của cổng mạng, những file ảnh tải về có thể bị chậm đi, nhưng bản thân phần mềm MinIO sẽ không sập. |

**4.4. Xác thực yêu cầu về Khả năng mở rộng (Scalability)**

|     |     |     |
| --- | --- | --- |
| **Thuộc tính chất lượng (Quality Attribute)** | **Sự cố giả định (Stimulus)** | **Phản hồi của hệ thống (Response)** |
| **4\. Khả năng mở rộng (Scalability)**<br><br>_(Khả năng đáp ứng khi lượng truy cập hoặc dữ liệu tăng đột biến)_ | **Sự cố 1:** Bộ truyện "One Piece" ra chương mới, lượng người dùng truy cập vào xem cùng lúc tăng gấp 20 lần bình thường. | Có ba lớp để scale cho vấn đề:<br><br>Lớp 1: Đỡ tải Database bằng Redis Cluster (In-memory Cache)<br><br>Thay vì bắt Database đọc dữ liệu từ ổ cứng, hệ thống của nhóm dùng Redis - cơ sở dữ liệu lưu trữ hoàn toàn trên RAM. Khi Uploader vừa đăng chương mới của "One Piece", Catalog Service đã chủ động nạp sẵn (Cache Warming) các thông tin metadata (Tên truyện, số trang, danh sách URL ảnh) lên RAM của Redis. Khi luồng traffic khổng lồ x20 lần ập đến, các request chỉ đi đến RAM (tốc độ phản hồi tính bằng micro-giây) và cache hit về ngay lập tức. Cụm Database ở phía sau hầu như không cảm nhận được lượng trafic khổng lồ này, duy trì sự ổn định cho các tính năng khác.<br><br>Lớp 2: Gánh tải băng thông bằng MinIO (Object Storage)<br><br>Như đã giải thích ở kịch bản bảo mật, Catalog API chỉ trả về chuỗi text rất nhẹ (Presigned URLs). Trách nhiệm truyền tải hàng Terabyte hình ảnh được giao phó hoàn toàn cho cụm MinIO Cluster. Khác với máy chủ Backend thông thường, máy chủ MinIO được thiết kế chuyên dụng cho I/O mạng (sẵn tiện, I/O luôn là một trong những thao tác gây hao tổn performance nặng nề nhất cho bất kỳ hệ thống nào). Nếu lưu lượng quá lớn, nhóm chỉ cần gắn thêm các ổ cứng hoặc thêm các node MinIO vật lý mới vào cụm, băng thông tải ảnh sẽ được phân tán đều. Kiến trúc này cho phép scale theo chiều ngang cực kỳ thuận tiện, cho bất kỳ tình huống tải lớn nào.<br><br>Lớp 3: Co giãn CPU bằng Docker Swarm (Auto-scaling)<br><br>Dù Redis và MinIO đã gánh phần nặng nhất, bản thân Catalog API vẫn phải dùng CPU để phân tích (parse) các HTTP Request, kiểm tra JWT Token của người dùng, và định tuyến. Khi traffic x20 lần, CPU của container Catalog API hiện tại có thể chạm ngưỡng rất cao. Lúc này, cơ sở hạ tầng Docker Swarm sẽ nhận được cảnh báo từ hệ thống giám sát (Prometheus/Grafana). Cơ chế Horizontal Pod Autoscaling (HPA - Mở rộng theo chiều ngang) được kích hoạt. Thay vì chỉ có 2 container Catalog API chạy như bình thường, Swarm sẽ tự động "nhân bản" thành 5, 10, hoặc 20 container Catalog API nằm rải rác trên các máy chủ vật lý khác nhau trong Application Cluster. API Gateway lập tức chia đều 100,000 request đó cho 20 container mới này. Kết quả, tải CPU trên mỗi container giảm xuống mức an toàn. Toàn bộ quá trình này diễn ra tự động trong vài giây mà không cần kỹ sư hệ thống phải thao tác thủ công để cắm thêm RAM hay CPU.<br><br>Quá trình thu hồi tài nguyên (Scale-in): Khả năng mở rộng thực sự tốt là phải đi kèm với Tính đàn hồi (Elasticity) - tức là có nở ra được thì phải co lại được để tiết kiệm tiền server. Sau 2-3 tiếng, khi lượng người đọc truyện đã đọc xong và out ra, traffic trở về mức bình thường. Docker Swarm nhận thấy CPU của 20 container Catalog API đang rảnh rỗi. Nó sẽ tự động ra lệnh terminate bớt các container dư thừa, đưa hệ thống về lại trạng thái 2 container như ban đầu, tối ưu chi phí. |
| **Sự cố 2:** Các tool Crawl (ETL) đồng loạt đẩy 50,000 file ảnh chương truyện mới lên hệ thống vào lúc nửa đêm. | Để giải quyết bài toán này, Nhóm đã áp dụng mẫu kiến trúc Broker Architecture kết hợp với Background Jobs (Celery).<br><br>Bước 1: Fast Intake<br><br>Khi tool Crawl đẩy 50,000 ảnh lên, Media Upload Service chỉ làm đúng 2 việc rất nhẹ: Nhận file và cất tạm vào MinIO. Gửi một tin nhắn (Event/Message) có nội dung kiểu "Ê, có ảnh mới tên là ABC ở đường dẫn XYZ, cần kiểm duyệt nhé!" vào Apache Kafka. Toàn bộ quá trình này chỉ mất vài chục mili-giây. Sau đó, Service lập tức trả về phản hồi 200 OK cho tool Crawl. Kết quả, Tool Crawl đẩy xong 50,000 ảnh trong nháy mắt mà Media Upload Service không hề bị quá tải.<br><br>Bước 2: Apache Kafka đóng vai trò Buffer<br><br>Kafka là một hệ thống phân phối tin nhắn cực kỳ mạnh, được thiết kế để chịu tải hàng triệu tin nhắn mỗi giây. 50,000 sự kiện vừa được tạo ra sẽ nằm gọn gàng trong một Topic (hàng đợi) của Kafka. Kafka đóng vai trò như một hồ chứa, hứng toàn bộ tải lưu lượng này, bảo vệ các thành phần phía sau khỏi bị ngập.<br><br>Bước 3: Asynchronous Processing<br><br>Phía sau Kafka là các AI Worker Nodes (chạy Celery). Khác với API, các Worker này không bị ai hối thúc cả. Chúng đóng vai trò là "Consumer", từ từ pull từng tin nhắn từ Kafka về để xử lý (chạy mô hình AI). Nếu hệ thống chỉ có 2 AI Worker (năng lực xử lý ví dụ 10 ảnh/giây), thì 50,000 ảnh sẽ được giải quyết từ từ trong khoảng vài tiếng khá lâu, nhưng tuyệt nhiên không bao giờ sập vì lượng tải này. Vấn đề ở đây là dù có 50,000 hay 500,000 ảnh, CPU và RAM của AI Worker cũng chỉ hoạt động ở mức trần thiết kế (không bao giờ vượt quá 100%). Hệ thống không bao giờ bị nghẽn cổ chai (bottleneck) dẫn đến crash.<br><br>Mặc khác, nếu muốn xử lý ảnh nhanh hơn, quản trị viên chỉ cần cấp thêm vài máy chủ AI GPU Nodes mới vào cụm Docker Swarm. Nhờ cơ chế Consumer Group của Kafka, các tin nhắn trong hàng đợi sẽ lập tức được chia đều cho cả các Worker cũ và Worker mới. Quá trình Scale-out diễn ra tự nhiên mà không cần sửa bất kỳ dòng code nào. |

**4.5. Xác thực yêu cầu về Độ tin cậy (Reliability)**

|     |     |     |
| --- | --- | --- |
| **Thuộc tính chất lượng (Quality Attribute)** | **Sự cố giả định (Stimulus)** | **Phản hồi của hệ thống (Response)** |
| **5\. Độ tin cậy (Reliability)**<br><br>_(Khả năng hoạt động chính xác, đảm bảo toàn vẹn dữ liệu và không mất mát thông tin)_ | **Sự cố 1:** Trong lúc tiến trình ngầm (AI Worker) đang quét ảnh kiểm duyệt nội dung thì máy chủ AI Node đột nhiên bị cúp điện tắt phụp. | Về bản chất của Message và Broker, khi một file ảnh được tải lên, Media Upload Service tạo ra một sự kiện (Message) đưa vào hàng đợi của Kafka. Điểm quan trọng của Kafka là nó lưu trữ thông điệp trên ổ cứng (Persistent Storage), không phải chỉ trên RAM. Khi một tin nhắn đã vào Kafka, nó an toàn tuyệt đối. Các AI Worker chỉ đóng vai trò là Consumer (người lấy tin nhắn ra đọc và làm việc).<br><br>Đồng thời, Kafka cung cấp cơ chế Acknowledgment – ACK giúp đảm bảo độ tin cậy trong quá trình giao tiếp bất đồng bộ:<br><br>Bước 1: Worker nhận việc (Pulling): AI Worker A (Celery) kết nối đến Kafka và nói "Cho tôi xin một việc". Kafka gửi cho nó sự kiện "Hãy quét bức ảnh xyz.jpg".<br><br>Bước 2: Kafka chuyển trạng thái (Unacknowledged): Lúc này, Kafka không xóa sự kiện đó khỏi hàng đợi. Nó chỉ đánh dấu sự kiện đó là đang được xử lý (in-flight/unacknowledged) bởi Worker A và tạm thời che nó đi không cho các Worker khác thấy.<br><br>Bước 3: Worker Processing: Worker A tải ảnh từ MinIO xuống, load mô hình PyTorch Swin NSFW lên GPU và bắt đầu chạy suy luận. Lúc này sự cố xảy ra! Máy chủ AI Node chứa Worker A bị cúp điện tắt phụp.<br><br>Do bị sập, Worker A không bao giờ gửi được tín hiệu ACK (Tôi đã hoàn thành) về cho Kafka. Kafka phát hiện lỗi Timeout: Mỗi sự kiện giao cho Worker đều có một khoảng thời gian chờ (Timeout, ví dụ: 60 giây). Sau 60 giây không thấy Worker A phản hồi ACK (hoặc Kafka phát hiện Worker A đã ngắt kết nối mạng - Session Timeout), Kafka sẽ kết luận: "Worker A đã chết hoặc gặp lỗi". Ngay lập tức, Kafka gỡ bỏ trạng thái đang xử lý của sự kiện đó, và đưa nó hiển thị trở lại trong hàng đợi. Worker khác (nếu đang rảnh) sẽ đứng ra tiếp quản. Giả sử một AI Worker B (đang chạy trên một máy chủ khác vẫn có điện) sẽ lập tức nhìn thấy sự kiện này. Nó kéo sự kiện về và thực hiện quét bức ảnh xyz.jpg lại từ đầu. Khi Worker B chạy xong, update Database thành công, nó gửi tín hiệu ACK về Kafka. Lúc này, Kafka mới thực sự đánh dấu hoàn thành (Commit offset) và không giao sự kiện này cho ai nữa.<br><br>Toàn bộ quá trình trên trính là diễn giải cho nguyên lý "At-least-once delivery” của Message Broker như trong lý thuyết đã học. Mặc dù hệ thống có thể mất vài phút trễ nải (do phải đợi timeout và làm lại), nhưng quan trọng nhất là Tính toàn vẹn của dữ liệu được bảo vệ tuyệt đối. Không có bất kỳ một bức ảnh nào tải lên mà không qua màng lọc kiểm duyệt (Swin NSFW Filter) dù máy chủ chạy AI có bị sập cháy. Điều này đáp ứng hoàn hảo yêu cầu phi chức năng về quản lý chất lượng nội dung của nền tảng truyện tranh. |
| **Sự cố 2:** Trong quá trình chạy tiến trình Crawl & Đồng bộ dữ liệu (ETL) từ nguồn bên thứ 3 (Mangadex), API của họ đột nhiên trả về file JSON bị lỗi cấu trúc (corrupted). | Như đã mô tả trong Bài 3 (Tiến trình Crawl & Đồng bộ dữ liệu ETL), dữ liệu từ bên ngoài không bao giờ được phép đi thẳng vào nhà chính (Master DB). Nó bắt buộc phải đi qua một filter.<br><br>Bước 1: Extract (Trích xuất) & Intake Filter<br><br>Tiến trình Crawl (chạy định kỳ) gọi API Mangadex để lấy hàng ngàn object JSON. Dữ liệu này đi qua màng lọc đầu tiên là Intake Filter. Nó không lưu vào Master DB, mà lưu toàn bộ vào một vùng đệm gọi là Staging DB (Cơ sở dữ liệu tạm). Ví dụ: Nó tạo ra một lô (batch) dữ liệu mang mã số BATCH_1024 trong Staging DB.<br><br>Bước 2: Transform (Biến đổi & Xác thực)<br><br>Tiếp theo, dữ liệu trong BATCH_1024 đi qua các màng lọc kiểm tra tính hợp lệ (Validation Filters) và màng lọc chuẩn hóa (Translator Filter - như Bài 3 đề cập). Tại đây, màng lọc phát hiện ra JSON bị lỗi cấu trúc (corrupted) – ví dụ UUID bị sai định dạng, hoặc thiếu thông tin chương truyện. Màng lọc lập tức ném ra một Exception và đánh dấu lô BATCH_1024 này là FAILED.<br><br>Nhờ cơ chế Automated Rollback qua Kafka, khi lô dữ liệu bị đánh dấu FAILED, hệ thống không để rác nằm im đó, mà kích hoạt cơ chế tự phục hồi: Tiến trình ETL lập tức bắn một sự kiện CRAWL_BATCH_FAILED {batch_id: "1024"} vào Apache Kafka. Một con Worker chuyên dụng chạy ngầm mang tên Mangadex Rollback Worker (được nhóm thiết kế riêng ở Bài 2) đang lắng nghe trên Kafka sẽ chộp lấy sự kiện này. Worker này chạy các lệnh SQL để Rollback (Xóa sạch) toàn bộ các dòng dữ liệu, ID truyện, ID chương thuộc về BATCH_1024 khỏi Staging DB.<br><br>Cuối cung, quản trị viên được gửi một thông báo (qua Telegram/Email) về việc Mangadex API đang bị lỗi để theo dõi hoặc sửa lại code tool crawl. |

**4.6. Xác thực yêu cầu về Hiệu suất (Performance):** xác thực bằng phương pháp prototype (nếu có)

./.

Copyright©2026, &lt;Nhóm 17&gt;