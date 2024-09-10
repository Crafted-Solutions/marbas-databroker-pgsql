using System.Data.Common;
using MarBasBrokerEnginePgSQL.Lob;
using MarBasBrokerSQLCommon;
using MarBasBrokerSQLCommon.GrainTier;
using MarBasSchema.GrainTier;
using MarBasSchema.IO;

namespace MarBasBrokerEnginePgSQL.GrainTier
{
    internal sealed class GrainFileDataAdapter : GrainFileInlineDataAdapter
    {
        private readonly IDbConnectionProvider? _connectionProvider;

        public GrainFileDataAdapter(DbDataReader dataReader, IDbConnectionProvider? connectionProvider = null)
            : base(dataReader, null == connectionProvider ? GrainFileContentAccess.None : GrainFileContentAccess.OnDemand)
        {
            _connectionProvider = connectionProvider;
        }

        public override IStreamableContent? Content
        {
            get
            {
                if (null == _connectionProvider)
                {
                    return base.Content;
                }
                return new StreamableLob(new GrainFileBlobContext<PgSQLDialect, PgSQLParameterFactory>(_connectionProvider, Id, GetMappedColumnName()));
            }
            set => throw new NotImplementedException();
        }

    }
}