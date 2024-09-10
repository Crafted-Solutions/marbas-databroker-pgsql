using System.Data.Common;
using System.Globalization;
using MarBasBrokerSQLCommon;
using MarBasCommon;
using MarBasCommon.Reflection;
using MarBasSchema;
using Npgsql;
using NpgsqlTypes;

namespace MarBasBrokerEnginePgSQL
{
    public sealed class PgSQLParameterFactory : AbstractDbParameterFactory<PgSQLParameterFactory>
    {
        public override DbParameter Create(string name, Type type, object? value)
        {
            NpgsqlParameter result;
            Type? effectiveType = type ?? ((dynamic?)value)?.GetType();
            if (effectiveType?.IsGenericType ?? false && effectiveType?.GetGenericTypeDefinition() == typeof(Nullable<>))
            {
                effectiveType = Nullable.GetUnderlyingType(effectiveType)!;
            }
            if (typeof(Guid).IsAssignableFrom(effectiveType) || typeof(IIdentifiable).IsAssignableFrom(effectiveType))
            {
                result = new NpgsqlParameter(name, NpgsqlDbType.Uuid)
                {
                    Value = null == value ? null : (Guid)(dynamic)value
                };
            }
            else if (typeof(DateTime).IsAssignableFrom(effectiveType))
            {
                result = new NpgsqlParameter(name, NpgsqlDbType.TimestampTz)
                {
                    Value = null == value ? null : ((DateTime)(dynamic)value).ToUniversalTime()
                };
            }
            else if (typeof(CultureInfo).IsAssignableFrom(effectiveType))
            {
                result = new NpgsqlParameter(name, NpgsqlDbType.Varchar)
                {
                    Value = null == value ? null : ((dynamic)value).IetfLanguageTag
                };
            }
            else if (typeof(Enum).IsAssignableFrom(effectiveType))
            {
                result = new NpgsqlParameter(name, NpgsqlDbType.Integer)
                {
                    Value = (Int32?)value?.CastToReflected(Enum.GetUnderlyingType(effectiveType))
                };
            }
            else
            {
                result = new NpgsqlParameter(name, value);
            }
            if (null == result.Value)
            {
                result.Value = DBNull.Value;
            }
            return result;
        }

        public override DbParameter Update(DbParameter parameter, object? value, Type? type = null)
        {
            var result = parameter;
            var effectiveType = type ?? parameter.Value?.GetType() ?? value?.GetType();
            if (null != effectiveType && effectiveType.IsGenericType && effectiveType.GetGenericTypeDefinition() == typeof(Nullable<>))
            {
                effectiveType = Nullable.GetUnderlyingType(effectiveType)!;
            }
            if (typeof(Guid).IsAssignableFrom(effectiveType) || typeof(IIdentifiable).IsAssignableFrom(effectiveType))
            {
                result.Value = null == value ? null : (Guid)(dynamic)value;
            }
            else if (typeof(DateTime).IsAssignableFrom(effectiveType))
            {
                result.Value = null == value ? null : ((DateTime)(dynamic)value).ToUniversalTime();
            }
            else if (typeof(CultureInfo).IsAssignableFrom(effectiveType))
            {
                result.Value = null == value ? null : ((dynamic)value).IetfLanguageTag;
            }
            else if (typeof(Enum).IsAssignableFrom(effectiveType))
            {
                result.Value = (Int32?)value?.CastToReflected(Enum.GetUnderlyingType(effectiveType));
            }
            else
            {
                result.Value = value;
            }
            if (null == result.Value)
            {
                result.Value = DBNull.Value;
            }
            return result;
        }

        public override DbParameter PrepareTraitValueParameter(string paramName, TraitValueType valueType, object? value)
        {
            DbParameter result;
            switch (valueType)
            {
                case TraitValueType.Grain:
                case TraitValueType.File:
                    {
                        result = new NpgsqlParameter(paramName, NpgsqlDbType.Uuid)
                        {
                            Value = null == value ? null : (Guid)(dynamic)value
                        };
                        break;
                    }
                case TraitValueType.DateTime:
                    {
                        result = new NpgsqlParameter(paramName, NpgsqlDbType.TimestampTz)
                        {
                            Value = null == value ? null : ((DateTime)(dynamic)value).ToUniversalTime()
                        };
                        break;
                    }
                default:
                    {
                        result = new NpgsqlParameter(paramName, value);
                        break;
                    }
            }
            if (null == result.Value)
            {
                result.Value = DBNull.Value;
            }
            return result;
        }
    }
}
