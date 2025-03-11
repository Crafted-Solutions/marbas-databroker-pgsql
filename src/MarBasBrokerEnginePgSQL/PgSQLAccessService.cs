using CraftedSolutions.MarBasBrokerSQLCommon.Access;
using CraftedSolutions.MarBasSchema.Broker;
using Microsoft.Extensions.Logging;

namespace CraftedSolutions.MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLAccessService : SQLAccessService<PgSQLDialect>
    {
        public PgSQLAccessService(IBrokerContext context, IBrokerProfile profile, ILogger<PgSQLAccessService> logger) : base(context, profile, logger)
        {
        }
    }
}