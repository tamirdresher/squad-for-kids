/// <summary>
/// Sample code files for demo mode — showcasing common real-world C# issues.
/// </summary>
public static class DemoSamples
{
    /// <summary>
    /// A cache implementation with multiple subtle issues.
    /// Good for showing performance + design debate.
    /// </summary>
    public const string BuggyCache = """
        public class SimpleCache<TKey, TValue>
        {
            private readonly Dictionary<TKey, (TValue Value, DateTime ExpiresAt)> _store = new();
            private readonly int _maxSize;
            private int _hitCount;
            private int _missCount;

            public SimpleCache(int maxSize = 1000)
            {
                _maxSize = maxSize;
            }

            public TValue Get(TKey key)
            {
                if (_store.ContainsKey(key))
                {
                    var entry = _store[key];
                    if (entry.ExpiresAt > DateTime.Now)
                    {
                        _hitCount++;
                        return entry.Value;
                    }
                    _store.Remove(key);
                }
                _missCount++;
                return default!;
            }

            public void Set(TKey key, TValue value, int ttlSeconds = 300)
            {
                if (_store.Count >= _maxSize)
                {
                    // Eviction: remove first item
                    _store.Remove(_store.Keys.First());
                }
                _store[key] = (value, DateTime.Now.AddSeconds(ttlSeconds));
            }

            public double HitRatio => (double)_hitCount / (_hitCount + _missCount);

            public void Clear() => _store.Clear();
        }
        """;

    /// <summary>
    /// A file upload handler with multiple security issues.
    /// Perfect for the Security Hawk mode.
    /// </summary>
    public const string FileUploadHandler = """
        [ApiController]
        [Route("api/files")]
        public class FileController : ControllerBase
        {
            private readonly string _uploadPath = @"C:\uploads";

            [HttpPost("upload")]
            public async Task<IActionResult> Upload(IFormFile file, string? subfolder = null)
            {
                if (file == null) return BadRequest("No file");

                // Build destination path from user input
                var dest = Path.Combine(_uploadPath, subfolder ?? "", file.FileName);

                using var stream = new FileStream(dest, FileMode.Create);
                await file.CopyToAsync(stream);

                return Ok(new { path = dest, size = file.Length });
            }

            [HttpGet("download")]
            public IActionResult Download(string filename)
            {
                var path = Path.Combine(_uploadPath, filename);
                var bytes = System.IO.File.ReadAllBytes(path);
                return File(bytes, "application/octet-stream", filename);
            }

            [HttpDelete("delete")]
            public IActionResult Delete(string filename)
            {
                System.IO.File.Delete(Path.Combine(_uploadPath, filename));
                return Ok();
            }
        }
        """;
}
