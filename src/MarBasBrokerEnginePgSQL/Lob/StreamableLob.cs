using System.Data;
using MarBasBrokerSQLCommon.Lob;
using MarBasSchema.IO;
using Npgsql;

namespace MarBasBrokerEnginePgSQL.Lob
{
    internal sealed class StreamableLob : StreamableContent, IAsyncStreamableContent
    {
        private readonly IBlobContext _context;
        private bool _disposed;
        private IDbTransaction? _transaction;
        private Stream? _stream;

        public StreamableLob(IBlobContext context)
        {
            _context = context;
        }

        ~StreamableLob() => Dispose(false);

        public override Stream Stream
        {
            get
            {
                return GetStreamAsync().Result;
            }
            set => base.Stream = value;
        }

        public async Task<Stream> GetStreamAsync(CancellationToken cancellationToken = default)
        {
            if (_disposed || null != _data)
            {
                return base.Stream;
            }
            if (null != _stream)
            {
                return _stream;
            }
            var oid = await GetOid(cancellationToken);
            if (null != oid)
            {
                var conn = _context.Connection;
                if (ConnectionState.Open != conn.State)
                {
                    await conn.OpenAsync(cancellationToken);
                }
#pragma warning disable CS0618 // Type or member is obsolete
                var manager = new NpgsqlLargeObjectManager((NpgsqlConnection)conn);
#pragma warning restore CS0618 // Type or member is obsolete
                if (null == _transaction)
                {
                    _transaction = await conn.BeginTransactionAsync(cancellationToken);
                }
                _stream = await manager.OpenReadAsync((uint)oid, cancellationToken);
                return _stream;
            }
            return base.Stream;
        }

        private async Task<uint?> GetOid(CancellationToken cancellationToken)
        {
            return (uint?)await (await _context.GetCommandAsync(cancellationToken)).ExecuteScalarAsync(cancellationToken);
        }

        protected override void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    var conn = _transaction?.Connection;
                    _transaction?.Dispose();
                    _context?.Dispose();
                    if (null != conn && ConnectionState.Open == conn.State)
                    {
                        conn.Dispose();
                    }
                }
                _disposed = true;
            }
        }
    }
}