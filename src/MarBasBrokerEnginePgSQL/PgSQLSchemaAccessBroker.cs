using MarBasBrokerSQLCommon.BrokerImpl;
using MarBasSchema.Access;
using MarBasSchema.Broker;
using Microsoft.Extensions.Logging;

namespace MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLSchemaAccessBroker : AclManagementBroker<PgSQLDialect>, ISchemaAccessBroker, IAsyncSchemaAccessBroker
    {
        public PgSQLSchemaAccessBroker(IBrokerProfile profile, IBrokerContext context, IAsyncAccessService accessService, ILogger<PgSQLSchemaAccessBroker> logger)
            : base(profile, context, accessService, logger)
        {
        }
    }
}