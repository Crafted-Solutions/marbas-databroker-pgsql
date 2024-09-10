using System.Data.Common;
using MarBasBrokerEnginePgSQL.GrainTier;
using MarBasBrokerSQLCommon;
using MarBasBrokerSQLCommon.BrokerImpl;
using MarBasBrokerSQLCommon.GrainTier;
using MarBasSchema.Access;
using MarBasSchema.Broker;
using MarBasSchema.GrainTier;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace MarBasBrokerEnginePgSQL
{
    public class PgSQLSchemaBroker : GrainTransportBroker<PgSQLDialect>, ISchemaBroker, IAsyncSchemaBroker
    {
        #region Contruction
        public PgSQLSchemaBroker(IBrokerProfile profile, ILogger<PgSQLSchemaBroker> logger) : base(profile, logger)
        {
        }

        public PgSQLSchemaBroker(IBrokerProfile profile, IBrokerContext context, IAsyncAccessService accessService, ILogger<PgSQLSchemaBroker> logger) : base(profile, context, accessService, logger)
        {
        }

        #endregion

        #region Overrides
        protected override IGrainFile CreateFileAdapter(DbDataReader reader, GrainFileContentAccess loadContent = GrainFileContentAccess.OnDemand)
        {
            return new GrainFileDataAdapter(reader, GrainFileContentAccess.None == loadContent ? null : _profile);
        }

        protected override async Task<int> DeleteFileBlobAsync(DbConnection connection, IGrainFile file, CancellationToken cancellationToken = default)
        {
            using (var cmd = connection.CreateCommand())
            {
                cmd.CommandText = $"SELECT mb_unlink_file_lob(@{GeneralEntityDefaults.ParamId})";
                cmd.Parameters.Add(_profile.ParameterFactory.Create(GeneralEntityDefaults.ParamId, file.Id));

                return await cmd.ExecuteNonQueryAsync(cancellationToken);
            }
        }

        protected override async Task WriteFileBlobAsync(DbConnection connection, Stream content, object blobId, CancellationToken cancellationToken = default)
        {
#pragma warning disable CS0618 // Type or member is obsolete
            var manager = new NpgsqlLargeObjectManager((NpgsqlConnection)connection);
#pragma warning restore CS0618 // Type or member is obsolete
            using (var stream = await manager.OpenReadWriteAsync((uint)blobId, cancellationToken))
            {
                await stream.SetLength(0, cancellationToken);
                await content.CopyToAsync(stream, cancellationToken);
            }
        }
        protected override async Task CloneFileBlobInTA(Guid sourceFileId, Guid targetFileId, DbTransaction ta, CancellationToken cancellationToken)
        {
            uint? srcBlobId = null;
            uint? tgtBlobId = null;
            using (var cmd = ta.Connection!.CreateCommand())
            {
                cmd.CommandText = $"SELECT {MapFileColumn(nameof(IGrainFile.Content))} FROM {GrainFileDefaults.DataSourceFile} WHERE {GeneralEntityDefaults.FieldBaseId} = @{GeneralEntityDefaults.ParamId}";
                var param = _profile.ParameterFactory.Create(GeneralEntityDefaults.ParamId, sourceFileId);
                cmd.Parameters.Add(param);

                srcBlobId = (uint?)await cmd.ExecuteScalarAsync(cancellationToken);
                if (null == srcBlobId)
                {
                    throw new ApplicationException($"Failed to retrieve rowid for File {sourceFileId}");
                }

                _profile.ParameterFactory.Update(param, targetFileId);

                tgtBlobId = (uint?)await cmd.ExecuteScalarAsync(cancellationToken);
                if (null == tgtBlobId)
                {
                    throw new ApplicationException($"Failed to retrieve rowid for File {targetFileId}");
                }
            }
#pragma warning disable CS0618 // Type or member is obsolete
            var manager = new NpgsqlLargeObjectManager((NpgsqlConnection)ta.Connection!);
#pragma warning restore CS0618 // Type or member is obsolete
            using (var srcBlob = await manager.OpenReadWriteAsync((uint)srcBlobId, cancellationToken))
            using (var tgtBlob = await manager.OpenReadWriteAsync((uint)tgtBlobId, cancellationToken))
            {
                await srcBlob.CopyToAsync(tgtBlob, cancellationToken);
                await tgtBlob.FlushAsync(cancellationToken);
            }

        }
        #endregion
    }

}
