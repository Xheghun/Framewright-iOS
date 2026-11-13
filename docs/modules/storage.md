# Session storage

`FramewrightSessionStore` serializes access to an app-owned directory. Use one writer per directory.
`save` replaces a versioned snapshot atomically. A successful save is a committed-file acknowledgement,
not a power-loss guarantee. Count and byte limits reject writes before replacing prior committed data;
this initial implementation requires explicit deletion to free space.

`PersistentDiagnosticSink` is an optional bounded bridge from the analytics pipeline. Pass it as a sink,
then await `flush()` before reading through the store or `close()` to drain and stop the bridge.
A successful enqueue is not a committed write. Overflow is reported to the analytics pipeline;
a failed disk write is reported by flush and close. A session can be marked delivery-incomplete by
saving a merged snapshot, separately from truncated analytics history.

The bridge persists accepted events independently of the bounded in-memory history. It rewrites
a snapshot per event; large-session write amplification needs profiling before release.
