using CraftedSolutions.MarBasBrokerSQLCommon;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace CraftedSolutions.MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLProfile : SQLBrokerProfile<NpgsqlConnection, NpgsqlConnectionStringBuilder>
    {
        public static readonly Version SchemaVersion = new(0, 1, 15);

        public PgSQLProfile(IConfiguration configuration, ILogger<PgSQLProfile> logger)
            : base(configuration, logger)
        {
        }

        public override Version Version => SchemaVersion;

        public override IDbParameterFactory ParameterFactory => PgSQLParameterFactory.Instance;

        protected override NpgsqlConnectionStringBuilder ConnectionSettings
        {
            get
            {
                if (string.IsNullOrEmpty(_connectionSettings.Host))
                {
                    _connectionSettings.Host = _configuration.GetValue("BrokerProfile:Host", "db-devel.marbas.local")!;
                    _connectionSettings.Port = _configuration.GetValue("BrokerProfile:Port", 5432);
                    _connectionSettings.Database = _configuration.GetValue("BrokerProfile:Database", "marbas");
                    _connectionSettings.Username = _configuration.GetValue("BrokerProfile:Username", "marbas");
                    _connectionSettings.Password = _configuration.GetValue("BrokerProfile:Password", "marbas");

                    _connectionSettings.Pooling = _configuration.GetValue("BrokerProfile:Pooling", true);
                    _connectionSettings.SslMode = _configuration.GetValue("BrokerProfile:SslMode", SslMode.Prefer);
                }
                return _connectionSettings;
            }
        }

        protected override async Task<bool> CanConnectAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                using var conn = Connection;
                await conn.OpenAsync(cancellationToken);
            }
            catch (Exception e) when (e is not SystemException)
            {
                _logger.LogError(e, "Failed to connect to {database} at {host}", ConnectionSettings.Database, ConnectionSettings.Host);
                return false;
            }
            return true;
        }
    }
}
