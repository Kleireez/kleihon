/// ID gabungan yang dipakai di database dan UI: "sourceId:remoteId".
String makeEntityId(String sourceId, String remoteId) => '$sourceId:$remoteId';

/// Kebalikan [makeEntityId]: mengambil remoteId dari ID gabungan milik
/// [sourceId]. ID yang tidak berawalan sourceId dikembalikan apa adanya.
String remoteIdFromEntityId(String sourceId, String entityId) {
  final prefix = '$sourceId:';
  return entityId.startsWith(prefix)
      ? entityId.substring(prefix.length)
      : entityId;
}
