// 桥接头：把系统 zlib 暴露给 Swift 内核。
// 本工程的 project.pbxproj 已经配好了：
//   SWIFT_OBJC_BRIDGING_HEADER = BridgingHeader.h
//   OTHER_LDFLAGS = -lz
// 不需要在 Xcode 里再点什么设置。
#include <zlib.h>

static inline uint32_t jy_crc32(uint32_t seed, const unsigned char *buf, uint32_t len) {
    return (uint32_t)crc32((uLong)seed, (const Bytef *)buf, (uLong)len);
}

static inline int jy_deflate(z_streamp strm, int flush) { return deflate(strm, flush); }
static inline int jy_inflate(z_streamp strm, int flush) { return inflate(strm, flush); }
