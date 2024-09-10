using MarBasBrokerSQLCommon.Access;
using MarBasSchema.Broker;
using Microsoft.Extensions.Logging;

namespace MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLAccessService : SQLAccessService<PgSQLDialect>
    {
        public PgSQLAccessService(IBrokerContext context, IBrokerProfile profile, ILogger<PgSQLAccessService> logger) : base(context, profile, logger)
        {
        }
    }
}