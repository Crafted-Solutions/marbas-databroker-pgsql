using CraftedSolutions.MarBasBrokerSQLCommon;

namespace CraftedSolutions.MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLDialect : ISQLDialect
    {
        public string SubsrringFunc => "substring";

        public string GuidGen => "gen_random_uuid()";

        public string ComparableDate(string dateExpression) => dateExpression;

        public string SignedToUnsigned(string numberExpression) => $"(CAST({numberExpression} AS bigint) & 0xffffffff)";

        public string ConflictExcluded(string fieldName) => $"excluded.{fieldName}";

        public string NewBlobContent(string? sizeParam = null) => $"lo_creat(-1)";

        public bool BlobUpdateRequiresReset => false;

        public string ReturnFromInsert => " RETURNING *";

        public string GuidGenPerRow(string rowDiscriminator) => GuidGen;

        public string ReturnExistingBlobID(string table, string? column = null, string? param = null) => $" RETURNING {column}";

        //public string ReturnNewBlobID(string table, string? column, string? param) => $"; SELECT {column} FROM {table} WHERE {GeneralEntityDefaults.FieldBaseId} = {param}";
        public string ReturnNewBlobID(string table, string? column, string? param) => $" RETURNING {column}";
    }
}
