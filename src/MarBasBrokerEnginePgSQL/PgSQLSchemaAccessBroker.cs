using CraftedSolutions.MarBasBrokerSQLCommon.BrokerImpl;
using CraftedSolutions.MarBasSchema.Access;
using CraftedSolutions.MarBasSchema.Broker;
using Microsoft.Extensions.Logging;

namespace CraftedSolutions.MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLSchemaAccessBroker : AclManagementBroker<PgSQLDialect>, ISchemaAccessBroker, IAsyncSchemaAccessBroker
    {
        public PgSQLSchemaAccessBroker(IBrokerProfile profile, IBrokerContext context, IAsyncAccessService accessService, ILogger<PgSQLSchemaAccessBroker> logger)
            : base(profile, context, accessService, logger)
        {
        }
    }
}