import argparse
import urllib.request
import urllib.parse
from html.parser import HTMLParser
import time
import random
from concurrent.futures import ThreadPoolExecutor, as_completed
import sys
import os
import threading

class LinkParser(HTMLParser):
    def __init__(self, base_url):
        super().__init__()
        self.base_url = base_url
        self.links = set()

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for name, value in attrs:
                if name == 'href':
                    full_url = urllib.parse.urljoin(self.base_url, value).split('#')[0].rstrip('/')
                    self.links.add(full_url)

class WebCrawlTester:
    def __init__(self, base_url, file_path="urls.txt", concurrency=10):
        parsed_base = urllib.parse.urlparse(base_url)
        if not parsed_base.scheme:
            base_url = "http://" + base_url
            parsed_base = urllib.parse.urlparse(base_url)
        
        self.base_url = base_url.rstrip('/')
        self.domain = parsed_base.netloc
        self.scheme = parsed_base.scheme
        self.file_path = file_path
        self.concurrency = concurrency
        self.discovered_urls = set()
        self.print_lock = threading.Lock()

    def safe_print(self, *args, **kwargs):
        with self.print_lock:
            print(*args, **kwargs)

    def is_internal(self, url):
        parsed = urllib.parse.urlparse(url)
        return parsed.netloc == '' or parsed.netloc == self.domain

    def crawl(self):
        self.safe_print(f"[*] Starting crawl from {self.base_url}...")
        queue = [self.base_url]
        self.discovered_urls.add(self.base_url)
        visited = set()
        
        while queue:
            url = queue.pop(0)
            if url in visited:
                continue
            visited.add(url)
            
            try:
                t0 = time.time()
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req, timeout=5) as response:
                    ttfb = (time.time() - t0) * 1000
                    content = response.read()
                    total_time = (time.time() - t0) * 1000
                    size_kb = len(content) / 1024
                    
                    self.safe_print(f"[CRAWL] {url:<60} | {size_kb:>7.2f} KB | TTFB: {ttfb:>6.1f}ms | Total: {total_time:>6.1f}ms")
                    
                    content_type = response.info().get_content_type()
                    if 'text/html' in content_type:
                        parser = LinkParser(url)
                        parser.feed(content.decode('utf-8', errors='ignore'))
                        
                        for link in parser.links:
                            if self.is_internal(link):
                                parsed_link = urllib.parse.urlparse(link)
                                if parsed_link.netloc == '':
                                    link = f"{self.scheme}://{self.domain}{parsed_link.path}"
                                
                                if link not in self.discovered_urls:
                                    if urllib.parse.urlparse(link).netloc == self.domain:
                                        self.discovered_urls.add(link)
                                        queue.append(link)
            except Exception as e:
                self.safe_print(f"[!] Error crawling {url}: {e}")

        self.save_urls()
        self.safe_print(f"[*] Crawl complete. {len(self.discovered_urls)} URLs found.")

    def save_urls(self):
        with open(self.file_path, 'w') as f:
            for url in sorted(self.discovered_urls):
                f.write(url + '\n')
        self.safe_print(f"[*] Saved {len(self.discovered_urls)} URLs to {self.file_path}")

    def load_urls(self):
        if not os.path.exists(self.file_path):
            self.safe_print(f"[!] File {self.file_path} not found. Run with --scan first.")
            sys.exit(1)
        with open(self.file_path, 'r') as f:
            self.discovered_urls = {line.strip() for line in f if line.strip()}
        self.safe_print(f"[*] Loaded {len(self.discovered_urls)} URLs from {self.file_path}")

    def load_test(self, num_requests):
        if not self.discovered_urls:
            self.safe_print("[!] No URLs to test.")
            return

        urls_list = list(self.discovered_urls)
        self.safe_print(f"[*] Starting load test (Concurrency: {self.concurrency}, Total: {num_requests})")
        self.safe_print(f"{'URL':<60} | Status | {'Size':>8} | {'TTFB':>8} | {'Total':>8}")
        self.safe_print("-" * 110)
        
        stats = {
            "success": 0, 
            "failure": 0, 
            "latencies": [], 
            "ttfb_list": [],
            "error_codes": {}
        }
        start_time = time.time()

        def fetch_page():
            target = random.choice(urls_list)
            try:
                t0 = time.time()
                req = urllib.request.Request(target, headers={'User-Agent': 'Mozilla/5.0'})
                # urlopen returns when headers are received -> TTFB
                with urllib.request.urlopen(req, timeout=10) as resp:
                    ttfb = (time.time() - t0) * 1000
                    code = resp.getcode()
                    content = resp.read()
                    total_time = (time.time() - t0) * 1000
                    size_kb = len(content) / 1024
                    return code, size_kb, ttfb, total_time, target
            except urllib.error.HTTPError as e:
                return e.code, 0, 0, 0, target
            except Exception as e:
                return str(e), 0, 0, 0, target

        with ThreadPoolExecutor(max_workers=self.concurrency) as executor:
            futures = [executor.submit(fetch_page) for _ in range(num_requests)]
            for future in as_completed(futures):
                res, size, ttfb, total, url = future.result()
                
                status_str = str(res)
                if isinstance(res, int) and 200 <= res < 400:
                    stats["success"] += 1
                    stats["latencies"].append(total / 1000.0)
                    stats["ttfb_list"].append(ttfb / 1000.0)
                else:
                    stats["failure"] += 1
                    stats["error_codes"][status_str] = stats["error_codes"].get(status_str, 0) + 1
                
                self.safe_print(f"{url[:60]:<60} | {status_str:>6} | {size:>5.1f} KB | {ttfb:>6.1f}ms | {total:>6.1f}ms")

        duration = time.time() - start_time
        avg_latency = sum(stats["latencies"]) / len(stats["latencies"]) if stats["latencies"] else 0
        avg_ttfb = sum(stats["ttfb_list"]) / len(stats["ttfb_list"]) if stats["ttfb_list"] else 0
        
        self.safe_print("\n" + "="*50)
        self.safe_print("            LOAD TEST SUMMARY")
        self.safe_print("="*50)
        self.safe_print(f"Total Requests:     {num_requests}")
        self.safe_print(f"Successful (2xx):   {stats['success']}")
        self.safe_print(f"Failed (non-2xx):   {stats['failure']}")
        
        if stats["error_codes"]:
            self.safe_print("\nError Code Breakdown:")
            for code, count in sorted(stats["error_codes"].items()):
                self.safe_print(f"  {code}: {count}")
        
        self.safe_print(f"\nTotal Duration:     {duration:.2f}s")
        self.safe_print(f"Avg Latency (Total): {avg_latency*1000:.1f}ms")
        self.safe_print(f"Avg TTFB:           {avg_ttfb*1000:.1f}ms")
        self.safe_print(f"Throughput (RPS):   {num_requests/duration:.2f} req/s")
        self.safe_print("="*50)

def main():
    parser = argparse.ArgumentParser(description="Web Crawler and Load Tester (Smart Defaults)")
    parser.add_argument("--url", default="https://oldsezam.net", help="Base URL to start crawling")
    parser.add_argument("--scan", action="store_true", help="Force run the crawler")
    parser.add_argument("--load", action="store_true", help="Force run the load test (requires urls.txt)")
    parser.add_argument("--file", default="urls.txt", help="File to save/load discovered URLs")
    parser.add_argument("--concurrency", type=int, default=10, help="Number of concurrent threads")
    parser.add_argument("--requests", type=int, default=100, help="Total number of requests for load test")
    
    args = parser.parse_args()

    tester = WebCrawlTester(args.url, file_path=args.file, concurrency=args.concurrency)

    # Check for existing URLs to determine smart default
    existing_urls = []
    if os.path.exists(args.file):
        with open(args.file, 'r') as f:
            existing_urls = [line.strip() for line in f if line.strip()]

    if args.scan:
        # Force scan
        tester.crawl()
    elif args.load:
        # Force load
        tester.load_urls()
        tester.load_test(args.requests)
    elif existing_urls:
        # Smart default: file exists, go straight to load test
        print(f"[*] Found {len(existing_urls)} URLs in {args.file}. Starting load test...")
        tester.discovered_urls = set(existing_urls)
        tester.load_test(args.requests)
    else:
        # Smart default: no file or empty, start crawling
        print(f"[*] No cached URLs found in {args.file}. Starting crawl...")
        tester.crawl()
        # Optionally perform load test after initial crawl
        if tester.discovered_urls:
            tester.load_test(args.requests)

if __name__ == "__main__":
    main()
