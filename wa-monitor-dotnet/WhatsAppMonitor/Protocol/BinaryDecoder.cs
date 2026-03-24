// BinaryDecoder.cs — WhatsApp Binary XML decoder
// Ported from whatsmeow Go reference (tulir/whatsmeow):
//   binary/token/token.go  — token dictionaries
//   binary/decoder.go      — decode logic
// Issue: #1034

using System.Text;

namespace WhatsAppMonitor.Protocol;

// ─── JID (Jabber ID) ─────────────────────────────────────────────────────────

/// <summary>
/// Jabber Identifier used by WhatsApp.
/// </summary>
public sealed record Jid(string User, string Server, ushort Device = 0, byte Agent = 0, ushort Integrator = 0)
{
    public static readonly string ServerWhatsApp    = "s.whatsapp.net";
    public static readonly string ServerGroup       = "g.us";
    public static readonly string ServerBroadcast   = "broadcast";
    public static readonly string ServerMessenger   = "msgr";
    public static readonly string ServerInterop     = "interop";
    public static readonly string ServerLid         = "lid";

    public bool IsEmpty => string.IsNullOrEmpty(User) && string.IsNullOrEmpty(Server);

    public override string ToString() => Device > 0
        ? $"{User}:{Device}@{Server}"
        : string.IsNullOrEmpty(User)
            ? Server
            : $"{User}@{Server}";
}

// ─── BinaryNode ───────────────────────────────────────────────────────────────

/// <summary>
/// Represents a decoded WhatsApp binary XML node.
/// Content is one of: null, string, byte[], BinaryNode[].
/// </summary>
public sealed class BinaryNode
{
    public string Tag   { get; init; } = "";
    public IReadOnlyDictionary<string, object?> Attrs { get; init; } = EmptyAttrs;
    /// <summary>null | string | byte[] | BinaryNode[]</summary>
    public object? Content { get; init; }

    private static readonly Dictionary<string, object?> EmptyAttrs = new();

    public string? GetAttrString(string key)
        => Attrs.TryGetValue(key, out var v) ? v?.ToString() : null;

    public override string ToString()
    {
        var sb = new StringBuilder();
        sb.Append('<').Append(Tag);
        foreach (var (k, v) in Attrs)
            sb.Append(' ').Append(k).Append("=\"").Append(v).Append('"');
        if (Content is null)
        {
            sb.Append(" />");
        }
        else
        {
            sb.Append('>');
            switch (Content)
            {
                case string s:    sb.Append(s); break;
                case byte[] b:    sb.Append('[').Append(b.Length).Append(" bytes]"); break;
                case BinaryNode[] nodes:
                    foreach (var n in nodes) sb.Append(n);
                    break;
            }
            sb.Append("</").Append(Tag).Append('>');
        }
        return sb.ToString();
    }
}

// ─── Token constants ──────────────────────────────────────────────────────────

internal static class WaTokens
{
    internal const int ListEmpty   = 0;
    internal const int Dictionary0 = 236;
    internal const int Dictionary1 = 237;
    internal const int Dictionary2 = 238;
    internal const int Dictionary3 = 239;
    internal const int InteropJID  = 245;
    internal const int FBJID       = 246;
    internal const int ADJID       = 247;
    internal const int List8       = 248;
    internal const int List16      = 249;
    internal const int JIDPair     = 250;
    internal const int Hex8        = 251;
    internal const int Binary8     = 252;
    internal const int Binary20    = 253;
    internal const int Binary32    = 254;
    internal const int Nibble8     = 255;

    internal const int DictVersion = 3;

    // 236 single-byte tokens (indices 0-235)
    // Ported verbatim from whatsmeow binary/token/token.go
    internal static readonly string[] SingleByte =
    [
        /* 000 */ "",
        /* 001 */ "xmlstreamstart",
        /* 002 */ "xmlstreamend",
        /* 003 */ "s.whatsapp.net",
        /* 004 */ "type",
        /* 005 */ "participant",
        /* 006 */ "from",
        /* 007 */ "receipt",
        /* 008 */ "id",
        /* 009 */ "notification",
        /* 010 */ "disappearing_mode",
        /* 011 */ "status",
        /* 012 */ "jid",
        /* 013 */ "broadcast",
        /* 014 */ "user",
        /* 015 */ "devices",
        /* 016 */ "device_hash",
        /* 017 */ "to",
        /* 018 */ "offline",
        /* 019 */ "message",
        /* 020 */ "result",
        /* 021 */ "class",
        /* 022 */ "xmlns",
        /* 023 */ "duration",
        /* 024 */ "notify",
        /* 025 */ "iq",
        /* 026 */ "t",
        /* 027 */ "ack",
        /* 028 */ "g.us",
        /* 029 */ "enc",
        /* 030 */ "urn:xmpp:whatsapp:push",
        /* 031 */ "presence",
        /* 032 */ "config_value",
        /* 033 */ "picture",
        /* 034 */ "verified_name",
        /* 035 */ "config_code",
        /* 036 */ "key-index-list",
        /* 037 */ "contact",
        /* 038 */ "mediatype",
        /* 039 */ "routing_info",
        /* 040 */ "edge_routing",
        /* 041 */ "get",
        /* 042 */ "read",
        /* 043 */ "urn:xmpp:ping",
        /* 044 */ "fallback_hostname",
        /* 045 */ "0",
        /* 046 */ "chatstate",
        /* 047 */ "business_hours_config",
        /* 048 */ "unavailable",
        /* 049 */ "download_buckets",
        /* 050 */ "skmsg",
        /* 051 */ "verified_level",
        /* 052 */ "composing",
        /* 053 */ "handshake",
        /* 054 */ "device-list",
        /* 055 */ "media",
        /* 056 */ "text",
        /* 057 */ "fallback_ip4",
        /* 058 */ "media_conn",
        /* 059 */ "device",
        /* 060 */ "creation",
        /* 061 */ "location",
        /* 062 */ "config",
        /* 063 */ "item",
        /* 064 */ "fallback_ip6",
        /* 065 */ "count",
        /* 066 */ "w:profile:picture",
        /* 067 */ "image",
        /* 068 */ "business",
        /* 069 */ "2",
        /* 070 */ "hostname",
        /* 071 */ "call-creator",
        /* 072 */ "display_name",
        /* 073 */ "relaylatency",
        /* 074 */ "platform",
        /* 075 */ "abprops",
        /* 076 */ "success",
        /* 077 */ "msg",
        /* 078 */ "offline_preview",
        /* 079 */ "prop",
        /* 080 */ "key-index",
        /* 081 */ "v",
        /* 082 */ "day_of_week",
        /* 083 */ "pkmsg",
        /* 084 */ "version",
        /* 085 */ "1",
        /* 086 */ "ping",
        /* 087 */ "w:p",
        /* 088 */ "download",
        /* 089 */ "video",
        /* 090 */ "set",
        /* 091 */ "specific_hours",
        /* 092 */ "props",
        /* 093 */ "primary",
        /* 094 */ "unknown",
        /* 095 */ "hash",
        /* 096 */ "commerce_experience",
        /* 097 */ "last",
        /* 098 */ "subscribe",
        /* 099 */ "max_buckets",
        /* 100 */ "call",
        /* 101 */ "profile",
        /* 102 */ "member_since_text",
        /* 103 */ "close_time",
        /* 104 */ "call-id",
        /* 105 */ "sticker",
        /* 106 */ "mode",
        /* 107 */ "participants",
        /* 108 */ "value",
        /* 109 */ "query",
        /* 110 */ "profile_options",
        /* 111 */ "open_time",
        /* 112 */ "code",
        /* 113 */ "list",
        /* 114 */ "host",
        /* 115 */ "ts",
        /* 116 */ "contacts",
        /* 117 */ "upload",
        /* 118 */ "lid",
        /* 119 */ "preview",
        /* 120 */ "update",
        /* 121 */ "usync",
        /* 122 */ "w:stats",
        /* 123 */ "delivery",
        /* 124 */ "auth_ttl",
        /* 125 */ "context",
        /* 126 */ "fail",
        /* 127 */ "cart_enabled",
        /* 128 */ "appdata",
        /* 129 */ "category",
        /* 130 */ "atn",
        /* 131 */ "direct_connection",
        /* 132 */ "decrypt-fail",
        /* 133 */ "relay_id",
        /* 134 */ "mmg-fallback.whatsapp.net",
        /* 135 */ "target",
        /* 136 */ "available",
        /* 137 */ "name",
        /* 138 */ "last_id",
        /* 139 */ "mmg.whatsapp.net",
        /* 140 */ "categories",
        /* 141 */ "401",
        /* 142 */ "is_new",
        /* 143 */ "index",
        /* 144 */ "tctoken",
        /* 145 */ "ip4",
        /* 146 */ "token_id",
        /* 147 */ "latency",
        /* 148 */ "recipient",
        /* 149 */ "edit",
        /* 150 */ "ip6",
        /* 151 */ "add",
        /* 152 */ "thumbnail-document",
        /* 153 */ "26",
        /* 154 */ "paused",
        /* 155 */ "true",
        /* 156 */ "identity",
        /* 157 */ "stream:error",
        /* 158 */ "key",
        /* 159 */ "sidelist",
        /* 160 */ "background",
        /* 161 */ "audio",
        /* 162 */ "3",
        /* 163 */ "thumbnail-image",
        /* 164 */ "biz-cover-photo",
        /* 165 */ "cat",
        /* 166 */ "gcm",
        /* 167 */ "thumbnail-video",
        /* 168 */ "error",
        /* 169 */ "auth",
        /* 170 */ "deny",
        /* 171 */ "serial",
        /* 172 */ "in",
        /* 173 */ "registration",
        /* 174 */ "thumbnail-link",
        /* 175 */ "remove",
        /* 176 */ "00",
        /* 177 */ "gif",
        /* 178 */ "thumbnail-gif",
        /* 179 */ "tag",
        /* 180 */ "capability",
        /* 181 */ "multicast",
        /* 182 */ "item-not-found",
        /* 183 */ "description",
        /* 184 */ "business_hours",
        /* 185 */ "config_expo_key",
        /* 186 */ "md-app-state",
        /* 187 */ "expiration",
        /* 188 */ "fallback",
        /* 189 */ "ttl",
        /* 190 */ "300",
        /* 191 */ "md-msg-hist",
        /* 192 */ "device_orientation",
        /* 193 */ "out",
        /* 194 */ "w:m",
        /* 195 */ "open_24h",
        /* 196 */ "side_list",
        /* 197 */ "token",
        /* 198 */ "inactive",
        /* 199 */ "01",
        /* 200 */ "document",
        /* 201 */ "te2",
        /* 202 */ "played",
        /* 203 */ "encrypt",
        /* 204 */ "msgr",
        /* 205 */ "hide",
        /* 206 */ "direct_path",
        /* 207 */ "12",
        /* 208 */ "state",
        /* 209 */ "not-authorized",
        /* 210 */ "url",
        /* 211 */ "terminate",
        /* 212 */ "signature",
        /* 213 */ "status-revoke-delay",
        /* 214 */ "02",
        /* 215 */ "te",
        /* 216 */ "linked_accounts",
        /* 217 */ "trusted_contact",
        /* 218 */ "timezone",
        /* 219 */ "ptt",
        /* 220 */ "kyc-id",
        /* 221 */ "privacy_token",
        /* 222 */ "readreceipts",
        /* 223 */ "appointment_only",
        /* 224 */ "address",
        /* 225 */ "expected_ts",
        /* 226 */ "privacy",
        /* 227 */ "7",
        /* 228 */ "android",
        /* 229 */ "interactive",
        /* 230 */ "device-identity",
        /* 231 */ "enabled",
        /* 232 */ "attribute_padding",
        /* 233 */ "1080",
        /* 234 */ "03",
        /* 235 */ "screen_height",
    ];

    // 4 double-byte dictionaries (Dictionary0–3), each with 256 entries.
    // Ported verbatim from whatsmeow binary/token/token.go
    internal static readonly string[][] DoubleByte =
    [
        // Dictionary0 (tag 236)
        [
            /* 000 */ "read-self",
            /* 001 */ "active",
            /* 002 */ "fbns",
            /* 003 */ "protocol",
            /* 004 */ "reaction",
            /* 005 */ "screen_width",
            /* 006 */ "heartbeat",
            /* 007 */ "deviceid",
            /* 008 */ "2:47DEQpj8",
            /* 009 */ "uploadfieldstat",
            /* 010 */ "voip_settings",
            /* 011 */ "retry",
            /* 012 */ "priority",
            /* 013 */ "longitude",
            /* 014 */ "conflict",
            /* 015 */ "false",
            /* 016 */ "ig_professional",
            /* 017 */ "replaced",
            /* 018 */ "preaccept",
            /* 019 */ "cover_photo",
            /* 020 */ "uncompressed",
            /* 021 */ "encopt",
            /* 022 */ "ppic",
            /* 023 */ "04",
            /* 024 */ "passive",
            /* 025 */ "status-revoke-drop",
            /* 026 */ "keygen",
            /* 027 */ "540",
            /* 028 */ "offer",
            /* 029 */ "rate",
            /* 030 */ "opus",
            /* 031 */ "latitude",
            /* 032 */ "w:gp2",
            /* 033 */ "ver",
            /* 034 */ "4",
            /* 035 */ "business_profile",
            /* 036 */ "medium",
            /* 037 */ "sender",
            /* 038 */ "prev_v_id",
            /* 039 */ "email",
            /* 040 */ "website",
            /* 041 */ "invited",
            /* 042 */ "sign_credential",
            /* 043 */ "05",
            /* 044 */ "transport",
            /* 045 */ "skey",
            /* 046 */ "reason",
            /* 047 */ "peer_abtest_bucket",
            /* 048 */ "America/Sao_Paulo",
            /* 049 */ "appid",
            /* 050 */ "refresh",
            /* 051 */ "100",
            /* 052 */ "06",
            /* 053 */ "404",
            /* 054 */ "101",
            /* 055 */ "104",
            /* 056 */ "107",
            /* 057 */ "102",
            /* 058 */ "109",
            /* 059 */ "103",
            /* 060 */ "member_add_mode",
            /* 061 */ "105",
            /* 062 */ "transaction-id",
            /* 063 */ "110",
            /* 064 */ "106",
            /* 065 */ "outgoing",
            /* 066 */ "108",
            /* 067 */ "111",
            /* 068 */ "tokens",
            /* 069 */ "followers",
            /* 070 */ "ig_handle",
            /* 071 */ "self_pid",
            /* 072 */ "tue",
            /* 073 */ "dec",
            /* 074 */ "thu",
            /* 075 */ "joinable",
            /* 076 */ "peer_pid",
            /* 077 */ "mon",
            /* 078 */ "features",
            /* 079 */ "wed",
            /* 080 */ "peer_device_presence",
            /* 081 */ "pn",
            /* 082 */ "delete",
            /* 083 */ "07",
            /* 084 */ "fri",
            /* 085 */ "audio_duration",
            /* 086 */ "admin",
            /* 087 */ "connected",
            /* 088 */ "delta",
            /* 089 */ "rcat",
            /* 090 */ "disable",
            /* 091 */ "collection",
            /* 092 */ "08",
            /* 093 */ "480",
            /* 094 */ "sat",
            /* 095 */ "phash",
            /* 096 */ "all",
            /* 097 */ "invite",
            /* 098 */ "accept",
            /* 099 */ "critical_unblock_low",
            /* 100 */ "group_update",
            /* 101 */ "signed_credential",
            /* 102 */ "blinded_credential",
            /* 103 */ "eph_setting",
            /* 104 */ "net",
            /* 105 */ "09",
            /* 106 */ "background_location",
            /* 107 */ "refresh_id",
            /* 108 */ "Asia/Kolkata",
            /* 109 */ "privacy_mode_ts",
            /* 110 */ "account_sync",
            /* 111 */ "voip_payload_type",
            /* 112 */ "service_areas",
            /* 113 */ "acs_public_key",
            /* 114 */ "v_id",
            /* 115 */ "0a",
            /* 116 */ "fallback_class",
            /* 117 */ "relay",
            /* 118 */ "actual_actors",
            /* 119 */ "metadata",
            /* 120 */ "w:biz",
            /* 121 */ "5",
            /* 122 */ "connected-limit",
            /* 123 */ "notice",
            /* 124 */ "0b",
            /* 125 */ "host_storage",
            /* 126 */ "fb_page",
            /* 127 */ "subject",
            /* 128 */ "privatestats",
            /* 129 */ "invis",
            /* 130 */ "groupadd",
            /* 131 */ "010",
            /* 132 */ "note.m4r",
            /* 133 */ "uuid",
            /* 134 */ "0c",
            /* 135 */ "8000",
            /* 136 */ "sun",
            /* 137 */ "372",
            /* 138 */ "1020",
            /* 139 */ "stage",
            /* 140 */ "1200",
            /* 141 */ "720",
            /* 142 */ "canonical",
            /* 143 */ "fb",
            /* 144 */ "011",
            /* 145 */ "video_duration",
            /* 146 */ "0d",
            /* 147 */ "1140",
            /* 148 */ "superadmin",
            /* 149 */ "012",
            /* 150 */ "Opening.m4r",
            /* 151 */ "keystore_attestation",
            /* 152 */ "dleq_proof",
            /* 153 */ "013",
            /* 154 */ "timestamp",
            /* 155 */ "ab_key",
            /* 156 */ "w:sync:app:state",
            /* 157 */ "0e",
            /* 158 */ "vertical",
            /* 159 */ "600",
            /* 160 */ "p_v_id",
            /* 161 */ "6",
            /* 162 */ "likes",
            /* 163 */ "014",
            /* 164 */ "500",
            /* 165 */ "1260",
            /* 166 */ "creator",
            /* 167 */ "0f",
            /* 168 */ "rte",
            /* 169 */ "destination",
            /* 170 */ "group",
            /* 171 */ "group_info",
            /* 172 */ "syncd_anti_tampering_fatal_exception_enabled",
            /* 173 */ "015",
            /* 174 */ "dl_bw",
            /* 175 */ "Asia/Jakarta",
            /* 176 */ "vp8/h.264",
            /* 177 */ "online",
            /* 178 */ "1320",
            /* 179 */ "fb:multiway",
            /* 180 */ "10",
            /* 181 */ "timeout",
            /* 182 */ "016",
            /* 183 */ "nse_retry",
            /* 184 */ "urn:xmpp:whatsapp:dirty",
            /* 185 */ "017",
            /* 186 */ "a_v_id",
            /* 187 */ "web_shops_chat_header_button_enabled",
            /* 188 */ "nse_call",
            /* 189 */ "inactive-upgrade",
            /* 190 */ "none",
            /* 191 */ "web",
            /* 192 */ "groups",
            /* 193 */ "2250",
            /* 194 */ "mms_hot_content_timespan_in_seconds",
            /* 195 */ "contact_blacklist",
            /* 196 */ "nse_read",
            /* 197 */ "suspended_group_deletion_notification",
            /* 198 */ "binary_version",
            /* 199 */ "018",
            /* 200 */ "https://www.whatsapp.com/otp/copy/",
            /* 201 */ "reg_push",
            /* 202 */ "shops_hide_catalog_attachment_entrypoint",
            /* 203 */ "server_sync",
            /* 204 */ ".",
            /* 205 */ "ephemeral_messages_allowed_values",
            /* 206 */ "019",
            /* 207 */ "mms_vcache_aggregation_enabled",
            /* 208 */ "iphone",
            /* 209 */ "America/Argentina/Buenos_Aires",
            /* 210 */ "01a",
            /* 211 */ "mms_vcard_autodownload_size_kb",
            /* 212 */ "nse_ver",
            /* 213 */ "shops_header_dropdown_menu_item",
            /* 214 */ "dhash",
            /* 215 */ "catalog_status",
            /* 216 */ "communities_mvp_new_iqs_serverprop",
            /* 217 */ "blocklist",
            /* 218 */ "default",
            /* 219 */ "11",
            /* 220 */ "ephemeral_messages_enabled",
            /* 221 */ "01b",
            /* 222 */ "original_dimensions",
            /* 223 */ "8",
            /* 224 */ "mms4_media_retry_notification_encryption_enabled",
            /* 225 */ "mms4_server_error_receipt_encryption_enabled",
            /* 226 */ "original_image_url",
            /* 227 */ "sync",
            /* 228 */ "multiway",
            /* 229 */ "420",
            /* 230 */ "companion_enc_static",
            /* 231 */ "shops_profile_drawer_entrypoint",
            /* 232 */ "01c",
            /* 233 */ "vcard_as_document_size_kb",
            /* 234 */ "status_video_max_duration",
            /* 235 */ "request_image_url",
            /* 236 */ "01d",
            /* 237 */ "regular_high",
            /* 238 */ "s_t",
            /* 239 */ "abt",
            /* 240 */ "share_ext_min_preliminary_image_quality",
            /* 241 */ "01e",
            /* 242 */ "32",
            /* 243 */ "syncd_key_rotation_enabled",
            /* 244 */ "data_namespace",
            /* 245 */ "md_downgrade_read_receipts2",
            /* 246 */ "patch",
            /* 247 */ "polltype",
            /* 248 */ "ephemeral_messages_setting",
            /* 249 */ "userrate",
            /* 250 */ "15",
            /* 251 */ "partial_pjpeg_bw_threshold",
            /* 252 */ "played-self",
            /* 253 */ "catalog_exists",
            /* 254 */ "01f",
            /* 255 */ "mute_v2",
        ],

        // Dictionary1 (tag 237)
        [
            /* 000 */ "reject",
            /* 001 */ "dirty",
            /* 002 */ "announcement",
            /* 003 */ "020",
            /* 004 */ "13",
            /* 005 */ "9",
            /* 006 */ "status_video_max_bitrate",
            /* 007 */ "fb:thrift_iq",
            /* 008 */ "offline_batch",
            /* 009 */ "022",
            /* 010 */ "full",
            /* 011 */ "ctwa_first_business_reply_logging",
            /* 012 */ "h.264",
            /* 013 */ "smax_id",
            /* 014 */ "group_description_length",
            /* 015 */ "https://www.whatsapp.com/otp/code",
            /* 016 */ "status_image_max_edge",
            /* 017 */ "smb_upsell_business_profile_enabled",
            /* 018 */ "021",
            /* 019 */ "web_upgrade_to_md_modal",
            /* 020 */ "14",
            /* 021 */ "023",
            /* 022 */ "s_o",
            /* 023 */ "smaller_video_thumbs_status_enabled",
            /* 024 */ "media_max_autodownload",
            /* 025 */ "960",
            /* 026 */ "blocking_status",
            /* 027 */ "peer_msg",
            /* 028 */ "joinable_group_call_client_version",
            /* 029 */ "group_call_video_maximization_enabled",
            /* 030 */ "return_snapshot",
            /* 031 */ "high",
            /* 032 */ "America/Mexico_City",
            /* 033 */ "entry_point_block_logging_enabled",
            /* 034 */ "pop",
            /* 035 */ "024",
            /* 036 */ "1050",
            /* 037 */ "16",
            /* 038 */ "1380",
            /* 039 */ "one_tap_calling_in_group_chat_size",
            /* 040 */ "regular_low",
            /* 041 */ "inline_joinable_education_enabled",
            /* 042 */ "hq_image_max_edge",
            /* 043 */ "locked",
            /* 044 */ "America/Bogota",
            /* 045 */ "smb_biztools_deeplink_enabled",
            /* 046 */ "status_image_quality",
            /* 047 */ "1088",
            /* 048 */ "025",
            /* 049 */ "payments_upi_intent_transaction_limit",
            /* 050 */ "voip",
            /* 051 */ "w:g2",
            /* 052 */ "027",
            /* 053 */ "md_pin_chat_enabled",
            /* 054 */ "026",
            /* 055 */ "multi_scan_pjpeg_download_enabled",
            /* 056 */ "shops_product_grid",
            /* 057 */ "transaction_id",
            /* 058 */ "ctwa_context_enabled",
            /* 059 */ "20",
            /* 060 */ "fna",
            /* 061 */ "hq_image_quality",
            /* 062 */ "alt_jpeg_doc_detection_quality",
            /* 063 */ "group_call_max_participants",
            /* 064 */ "pkey",
            /* 065 */ "America/Belem",
            /* 066 */ "image_max_kbytes",
            /* 067 */ "web_cart_v1_1_order_message_changes_enabled",
            /* 068 */ "ctwa_context_enterprise_enabled",
            /* 069 */ "urn:xmpp:whatsapp:account",
            /* 070 */ "840",
            /* 071 */ "Asia/Kuala_Lumpur",
            /* 072 */ "max_participants",
            /* 073 */ "video_remux_after_repair_enabled",
            /* 074 */ "stella_addressbook_restriction_type",
            /* 075 */ "660",
            /* 076 */ "900",
            /* 077 */ "780",
            /* 078 */ "context_menu_ios13_enabled",
            /* 079 */ "mute-state",
            /* 080 */ "ref",
            /* 081 */ "payments_request_messages",
            /* 082 */ "029",
            /* 083 */ "frsksmsg",
            /* 084 */ "vcard_max_size_kb",
            /* 085 */ "sample_buffer_gif_player_enabled",
            /* 086 */ "match_last_seen",
            /* 087 */ "510",
            /* 088 */ "4983",
            /* 089 */ "video_max_bitrate",
            /* 090 */ "028",
            /* 091 */ "w:comms:chat",
            /* 092 */ "17",
            /* 093 */ "frequently_forwarded_max",
            /* 094 */ "groups_privacy_blacklist",
            /* 095 */ "Asia/Karachi",
            /* 096 */ "02a",
            /* 097 */ "web_download_document_thumb_mms_enabled",
            /* 098 */ "02b",
            /* 099 */ "hist_sync",
            /* 100 */ "biz_block_reasons_version",
            /* 101 */ "1024",
            /* 102 */ "18",
            /* 103 */ "web_is_direct_connection_for_plm_transparent",
            /* 104 */ "view_once_write",
            /* 105 */ "file_max_size",
            /* 106 */ "paid_convo_id",
            /* 107 */ "online_privacy_setting",
            /* 108 */ "video_max_edge",
            /* 109 */ "view_once_read",
            /* 110 */ "enhanced_storage_management",
            /* 111 */ "multi_scan_pjpeg_encoding_enabled",
            /* 112 */ "ctwa_context_forward_enabled",
            /* 113 */ "video_transcode_downgrade_enable",
            /* 114 */ "template_doc_mime_types",
            /* 115 */ "hq_image_bw_threshold",
            /* 116 */ "30",
            /* 117 */ "body",
            /* 118 */ "u_aud_limit_sil_restarts_ctrl",
            /* 119 */ "other",
            /* 120 */ "participating",
            /* 121 */ "w:biz:directory",
            /* 122 */ "1110",
            /* 123 */ "vp8",
            /* 124 */ "4018",
            /* 125 */ "meta",
            /* 126 */ "doc_detection_image_max_edge",
            /* 127 */ "image_quality",
            /* 128 */ "1170",
            /* 129 */ "02c",
            /* 130 */ "smb_upsell_chat_banner_enabled",
            /* 131 */ "key_expiry_time_second",
            /* 132 */ "pid",
            /* 133 */ "stella_interop_enabled",
            /* 134 */ "19",
            /* 135 */ "linked_device_max_count",
            /* 136 */ "md_device_sync_enabled",
            /* 137 */ "02d",
            /* 138 */ "02e",
            /* 139 */ "360",
            /* 140 */ "enhanced_block_enabled",
            /* 141 */ "ephemeral_icon_in_forwarding",
            /* 142 */ "paid_convo_status",
            /* 143 */ "gif_provider",
            /* 144 */ "project_name",
            /* 145 */ "server-error",
            /* 146 */ "canonical_url_validation_enabled",
            /* 147 */ "wallpapers_v2",
            /* 148 */ "syncd_clear_chat_delete_chat_enabled",
            /* 149 */ "medianotify",
            /* 150 */ "02f",
            /* 151 */ "shops_required_tos_version",
            /* 152 */ "vote",
            /* 153 */ "reset_skey_on_id_change",
            /* 154 */ "030",
            /* 155 */ "image_max_edge",
            /* 156 */ "multicast_limit_global",
            /* 157 */ "ul_bw",
            /* 158 */ "21",
            /* 159 */ "25",
            /* 160 */ "5000",
            /* 161 */ "poll",
            /* 162 */ "570",
            /* 163 */ "22",
            /* 164 */ "031",
            /* 165 */ "1280",
            /* 166 */ "WhatsApp",
            /* 167 */ "032",
            /* 168 */ "bloks_shops_enabled",
            /* 169 */ "50",
            /* 170 */ "upload_host_switching_enabled",
            /* 171 */ "web_ctwa_context_compose_enabled",
            /* 172 */ "ptt_forwarded_features_enabled",
            /* 173 */ "unblocked",
            /* 174 */ "partial_pjpeg_enabled",
            /* 175 */ "fbid:devices",
            /* 176 */ "height",
            /* 177 */ "ephemeral_group_query_ts",
            /* 178 */ "group_join_permissions",
            /* 179 */ "order",
            /* 180 */ "033",
            /* 181 */ "alt_jpeg_status_quality",
            /* 182 */ "migrate",
            /* 183 */ "popular-bank",
            /* 184 */ "win_uwp_deprecation_killswitch_enabled",
            /* 185 */ "web_download_status_thumb_mms_enabled",
            /* 186 */ "blocking",
            /* 187 */ "url_text",
            /* 188 */ "035",
            /* 189 */ "web_forwarding_limit_to_groups",
            /* 190 */ "1600",
            /* 191 */ "val",
            /* 192 */ "1000",
            /* 193 */ "syncd_msg_date_enabled",
            /* 194 */ "bank-ref-id",
            /* 195 */ "max_subject",
            /* 196 */ "payments_web_enabled",
            /* 197 */ "web_upload_document_thumb_mms_enabled",
            /* 198 */ "size",
            /* 199 */ "request",
            /* 200 */ "ephemeral",
            /* 201 */ "24",
            /* 202 */ "receipt_agg",
            /* 203 */ "ptt_remember_play_position",
            /* 204 */ "sampling_weight",
            /* 205 */ "enc_rekey",
            /* 206 */ "mute_always",
            /* 207 */ "037",
            /* 208 */ "034",
            /* 209 */ "23",
            /* 210 */ "036",
            /* 211 */ "action",
            /* 212 */ "click_to_chat_qr_enabled",
            /* 213 */ "width",
            /* 214 */ "disabled",
            /* 215 */ "038",
            /* 216 */ "md_blocklist_v2",
            /* 217 */ "played_self_enabled",
            /* 218 */ "web_buttons_message_enabled",
            /* 219 */ "flow_id",
            /* 220 */ "clear",
            /* 221 */ "450",
            /* 222 */ "fbid:thread",
            /* 223 */ "bloks_session_state",
            /* 224 */ "America/Lima",
            /* 225 */ "attachment_picker_refresh",
            /* 226 */ "download_host_switching_enabled",
            /* 227 */ "1792",
            /* 228 */ "u_aud_limit_sil_restarts_test2",
            /* 229 */ "custom_urls",
            /* 230 */ "device_fanout",
            /* 231 */ "optimistic_upload",
            /* 232 */ "2000",
            /* 233 */ "key_cipher_suite",
            /* 234 */ "web_smb_upsell_in_biz_profile_enabled",
            /* 235 */ "e",
            /* 236 */ "039",
            /* 237 */ "siri_post_status_shortcut",
            /* 238 */ "pair-device",
            /* 239 */ "lg",
            /* 240 */ "lc",
            /* 241 */ "stream_attribution_url",
            /* 242 */ "model",
            /* 243 */ "mspjpeg_phash_gen",
            /* 244 */ "catalog_send_all",
            /* 245 */ "new_multi_vcards_ui",
            /* 246 */ "share_biz_vcard_enabled",
            /* 247 */ "-",
            /* 248 */ "clean",
            /* 249 */ "200",
            /* 250 */ "md_blocklist_v2_server",
            /* 251 */ "03b",
            /* 252 */ "03a",
            /* 253 */ "web_md_migration_experience",
            /* 254 */ "ptt_conversation_waveform",
            /* 255 */ "u_aud_limit_sil_restarts_test1",
        ],

        // Dictionary2 (tag 238)
        [
            /* 000 */ "64",
            /* 001 */ "ptt_playback_speed_enabled",
            /* 002 */ "web_product_list_message_enabled",
            /* 003 */ "paid_convo_ts",
            /* 004 */ "27",
            /* 005 */ "manufacturer",
            /* 006 */ "psp-routing",
            /* 007 */ "grp_uii_cleanup",
            /* 008 */ "ptt_draft_enabled",
            /* 009 */ "03c",
            /* 010 */ "business_initiated",
            /* 011 */ "web_catalog_products_onoff",
            /* 012 */ "web_upload_link_thumb_mms_enabled",
            /* 013 */ "03e",
            /* 014 */ "mediaretry",
            /* 015 */ "35",
            /* 016 */ "hfm_string_changes",
            /* 017 */ "28",
            /* 018 */ "America/Fortaleza",
            /* 019 */ "max_keys",
            /* 020 */ "md_mhfs_days",
            /* 021 */ "streaming_upload_chunk_size",
            /* 022 */ "5541",
            /* 023 */ "040",
            /* 024 */ "03d",
            /* 025 */ "2675",
            /* 026 */ "03f",
            /* 027 */ "...",
            /* 028 */ "512",
            /* 029 */ "mute",
            /* 030 */ "48",
            /* 031 */ "041",
            /* 032 */ "alt_jpeg_quality",
            /* 033 */ "60",
            /* 034 */ "042",
            /* 035 */ "md_smb_quick_reply",
            /* 036 */ "5183",
            /* 037 */ "c",
            /* 038 */ "1343",
            /* 039 */ "40",
            /* 040 */ "1230",
            /* 041 */ "043",
            /* 042 */ "044",
            /* 043 */ "mms_cat_v1_forward_hot_override_enabled",
            /* 044 */ "user_notice",
            /* 045 */ "ptt_waveform_send",
            /* 046 */ "047",
            /* 047 */ "Asia/Calcutta",
            /* 048 */ "250",
            /* 049 */ "md_privacy_v2",
            /* 050 */ "31",
            /* 051 */ "29",
            /* 052 */ "128",
            /* 053 */ "md_messaging_enabled",
            /* 054 */ "046",
            /* 055 */ "crypto",
            /* 056 */ "690",
            /* 057 */ "045",
            /* 058 */ "enc_iv",
            /* 059 */ "75",
            /* 060 */ "failure",
            /* 061 */ "ptt_oot_playback",
            /* 062 */ "REDACTED",
            /* 063 */ "w",
            /* 064 */ "048",
            /* 065 */ "2201",
            /* 066 */ "web_large_files_ui",
            /* 067 */ "Asia/Makassar",
            /* 068 */ "812",
            /* 069 */ "status_collapse_muted",
            /* 070 */ "1334",
            /* 071 */ "257",
            /* 072 */ "2HP4dm",
            /* 073 */ "049",
            /* 074 */ "patches",
            /* 075 */ "1290",
            /* 076 */ "43cY6T",
            /* 077 */ "America/Caracas",
            /* 078 */ "web_sticker_maker",
            /* 079 */ "campaign",
            /* 080 */ "ptt_pausable_enabled",
            /* 081 */ "33",
            /* 082 */ "42",
            /* 083 */ "attestation",
            /* 084 */ "biz",
            /* 085 */ "04b",
            /* 086 */ "query_linked",
            /* 087 */ "s",
            /* 088 */ "125",
            /* 089 */ "04a",
            /* 090 */ "810",
            /* 091 */ "availability",
            /* 092 */ "1411",
            /* 093 */ "responsiveness_v2_m1",
            /* 094 */ "catalog_not_created",
            /* 095 */ "34",
            /* 096 */ "America/Santiago",
            /* 097 */ "1465",
            /* 098 */ "enc_p",
            /* 099 */ "04d",
            /* 100 */ "status_info",
            /* 101 */ "04f",
            /* 102 */ "key_version",
            /* 103 */ "..",
            /* 104 */ "04c",
            /* 105 */ "04e",
            /* 106 */ "md_group_notification",
            /* 107 */ "1598",
            /* 108 */ "1215",
            /* 109 */ "web_cart_enabled",
            /* 110 */ "37",
            /* 111 */ "630",
            /* 112 */ "1920",
            /* 113 */ "2394",
            /* 114 */ "-1",
            /* 115 */ "vcard",
            /* 116 */ "38",
            /* 117 */ "elapsed",
            /* 118 */ "36",
            /* 119 */ "828",
            /* 120 */ "peer",
            /* 121 */ "pricing_category",
            /* 122 */ "1245",
            /* 123 */ "invalid",
            /* 124 */ "stella_ios_enabled",
            /* 125 */ "2687",
            /* 126 */ "45",
            /* 127 */ "1528",
            /* 128 */ "39",
            /* 129 */ "u_is_redial_audio_1104_ctrl",
            /* 130 */ "1025",
            /* 131 */ "1455",
            /* 132 */ "58",
            /* 133 */ "2524",
            /* 134 */ "2603",
            /* 135 */ "054",
            /* 136 */ "bsp_system_message_enabled",
            /* 137 */ "web_pip_redesign",
            /* 138 */ "051",
            /* 139 */ "verify_apps",
            /* 140 */ "1974",
            /* 141 */ "1272",
            /* 142 */ "1322",
            /* 143 */ "1755",
            /* 144 */ "052",
            /* 145 */ "70",
            /* 146 */ "050",
            /* 147 */ "1063",
            /* 148 */ "1135",
            /* 149 */ "1361",
            /* 150 */ "80",
            /* 151 */ "1096",
            /* 152 */ "1828",
            /* 153 */ "1851",
            /* 154 */ "1251",
            /* 155 */ "1921",
            /* 156 */ "key_config_id",
            /* 157 */ "1254",
            /* 158 */ "1566",
            /* 159 */ "1252",
            /* 160 */ "2525",
            /* 161 */ "critical_block",
            /* 162 */ "1669",
            /* 163 */ "max_available",
            /* 164 */ "w:auth:backup:token",
            /* 165 */ "product",
            /* 166 */ "2530",
            /* 167 */ "870",
            /* 168 */ "1022",
            /* 169 */ "participant_uuid",
            /* 170 */ "web_cart_on_off",
            /* 171 */ "1255",
            /* 172 */ "1432",
            /* 173 */ "1867",
            /* 174 */ "41",
            /* 175 */ "1415",
            /* 176 */ "1440",
            /* 177 */ "240",
            /* 178 */ "1204",
            /* 179 */ "1608",
            /* 180 */ "1690",
            /* 181 */ "1846",
            /* 182 */ "1483",
            /* 183 */ "1687",
            /* 184 */ "1749",
            /* 185 */ "69",
            /* 186 */ "url_number",
            /* 187 */ "053",
            /* 188 */ "1325",
            /* 189 */ "1040",
            /* 190 */ "365",
            /* 191 */ "59",
            /* 192 */ "Asia/Riyadh",
            /* 193 */ "1177",
            /* 194 */ "test_recommended",
            /* 195 */ "057",
            /* 196 */ "1612",
            /* 197 */ "43",
            /* 198 */ "1061",
            /* 199 */ "1518",
            /* 200 */ "1635",
            /* 201 */ "055",
            /* 202 */ "1034",
            /* 203 */ "1375",
            /* 204 */ "750",
            /* 205 */ "1430",
            /* 206 */ "event_code",
            /* 207 */ "1682",
            /* 208 */ "503",
            /* 209 */ "55",
            /* 210 */ "865",
            /* 211 */ "78",
            /* 212 */ "1309",
            /* 213 */ "1365",
            /* 214 */ "44",
            /* 215 */ "America/Guayaquil",
            /* 216 */ "535",
            /* 217 */ "LIMITED",
            /* 218 */ "1377",
            /* 219 */ "1613",
            /* 220 */ "1420",
            /* 221 */ "1599",
            /* 222 */ "1822",
            /* 223 */ "05a",
            /* 224 */ "1681",
            /* 225 */ "password",
            /* 226 */ "1111",
            /* 227 */ "1214",
            /* 228 */ "1376",
            /* 229 */ "1478",
            /* 230 */ "47",
            /* 231 */ "1082",
            /* 232 */ "4282",
            /* 233 */ "Europe/Istanbul",
            /* 234 */ "1307",
            /* 235 */ "46",
            /* 236 */ "058",
            /* 237 */ "1124",
            /* 238 */ "256",
            /* 239 */ "rate-overlimit",
            /* 240 */ "retail",
            /* 241 */ "u_a_socket_err_fix_succ_test",
            /* 242 */ "1292",
            /* 243 */ "1370",
            /* 244 */ "1388",
            /* 245 */ "520",
            /* 246 */ "861",
            /* 247 */ "psa",
            /* 248 */ "regular",
            /* 249 */ "1181",
            /* 250 */ "1766",
            /* 251 */ "05b",
            /* 252 */ "1183",
            /* 253 */ "1213",
            /* 254 */ "1304",
            /* 255 */ "1537",
        ],

        // Dictionary3 (tag 239)
        [
            /* 000 */ "1724",
            /* 001 */ "profile_picture",
            /* 002 */ "1071",
            /* 003 */ "1314",
            /* 004 */ "1605",
            /* 005 */ "407",
            /* 006 */ "990",
            /* 007 */ "1710",
            /* 008 */ "746",
            /* 009 */ "pricing_model",
            /* 010 */ "056",
            /* 011 */ "059",
            /* 012 */ "061",
            /* 013 */ "1119",
            /* 014 */ "6027",
            /* 015 */ "65",
            /* 016 */ "877",
            /* 017 */ "1607",
            /* 018 */ "05d",
            /* 019 */ "917",
            /* 020 */ "seen",
            /* 021 */ "1516",
            /* 022 */ "49",
            /* 023 */ "470",
            /* 024 */ "973",
            /* 025 */ "1037",
            /* 026 */ "1350",
            /* 027 */ "1394",
            /* 028 */ "1480",
            /* 029 */ "1796",
            /* 030 */ "keys",
            /* 031 */ "794",
            /* 032 */ "1536",
            /* 033 */ "1594",
            /* 034 */ "2378",
            /* 035 */ "1333",
            /* 036 */ "1524",
            /* 037 */ "1825",
            /* 038 */ "116",
            /* 039 */ "309",
            /* 040 */ "52",
            /* 041 */ "808",
            /* 042 */ "827",
            /* 043 */ "909",
            /* 044 */ "495",
            /* 045 */ "1660",
            /* 046 */ "361",
            /* 047 */ "957",
            /* 048 */ "google",
            /* 049 */ "1357",
            /* 050 */ "1565",
            /* 051 */ "1967",
            /* 052 */ "996",
            /* 053 */ "1775",
            /* 054 */ "586",
            /* 055 */ "736",
            /* 056 */ "1052",
            /* 057 */ "1670",
            /* 058 */ "bank",
            /* 059 */ "177",
            /* 060 */ "1416",
            /* 061 */ "2194",
            /* 062 */ "2222",
            /* 063 */ "1454",
            /* 064 */ "1839",
            /* 065 */ "1275",
            /* 066 */ "53",
            /* 067 */ "997",
            /* 068 */ "1629",
            /* 069 */ "6028",
            /* 070 */ "smba",
            /* 071 */ "1378",
            /* 072 */ "1410",
            /* 073 */ "05c",
            /* 074 */ "1849",
            /* 075 */ "727",
            /* 076 */ "create",
            /* 077 */ "1559",
            /* 078 */ "536",
            /* 079 */ "1106",
            /* 080 */ "1310",
            /* 081 */ "1944",
            /* 082 */ "670",
            /* 083 */ "1297",
            /* 084 */ "1316",
            /* 085 */ "1762",
            /* 086 */ "en",
            /* 087 */ "1148",
            /* 088 */ "1295",
            /* 089 */ "1551",
            /* 090 */ "1853",
            /* 091 */ "1890",
            /* 092 */ "1208",
            /* 093 */ "1784",
            /* 094 */ "7200",
            /* 095 */ "05f",
            /* 096 */ "178",
            /* 097 */ "1283",
            /* 098 */ "1332",
            /* 099 */ "381",
            /* 100 */ "643",
            /* 101 */ "1056",
            /* 102 */ "1238",
            /* 103 */ "2024",
            /* 104 */ "2387",
            /* 105 */ "179",
            /* 106 */ "981",
            /* 107 */ "1547",
            /* 108 */ "1705",
            /* 109 */ "05e",
            /* 110 */ "290",
            /* 111 */ "903",
            /* 112 */ "1069",
            /* 113 */ "1285",
            /* 114 */ "2436",
            /* 115 */ "062",
            /* 116 */ "251",
            /* 117 */ "560",
            /* 118 */ "582",
            /* 119 */ "719",
            /* 120 */ "56",
            /* 121 */ "1700",
            /* 122 */ "2321",
            /* 123 */ "325",
            /* 124 */ "448",
            /* 125 */ "613",
            /* 126 */ "777",
            /* 127 */ "791",
            /* 128 */ "51",
            /* 129 */ "488",
            /* 130 */ "902",
            /* 131 */ "Asia/Almaty",
            /* 132 */ "is_hidden",
            /* 133 */ "1398",
            /* 134 */ "1527",
            /* 135 */ "1893",
            /* 136 */ "1999",
            /* 137 */ "2367",
            /* 138 */ "2642",
            /* 139 */ "237",
            /* 140 */ "busy",
            /* 141 */ "065",
            /* 142 */ "067",
            /* 143 */ "233",
            /* 144 */ "590",
            /* 145 */ "993",
            /* 146 */ "1511",
            /* 147 */ "54",
            /* 148 */ "723",
            /* 149 */ "860",
            /* 150 */ "363",
            /* 151 */ "487",
            /* 152 */ "522",
            /* 153 */ "605",
            /* 154 */ "995",
            /* 155 */ "1321",
            /* 156 */ "1691",
            /* 157 */ "1865",
            /* 158 */ "2447",
            /* 159 */ "2462",
            /* 160 */ "NON_TRANSACTIONAL",
            /* 161 */ "433",
            /* 162 */ "871",
            /* 163 */ "432",
            /* 164 */ "1004",
            /* 165 */ "1207",
            /* 166 */ "2032",
            /* 167 */ "2050",
            /* 168 */ "2379",
            /* 169 */ "2446",
            /* 170 */ "279",
            /* 171 */ "636",
            /* 172 */ "703",
            /* 173 */ "904",
            /* 174 */ "248",
            /* 175 */ "370",
            /* 176 */ "691",
            /* 177 */ "700",
            /* 178 */ "1068",
            /* 179 */ "1655",
            /* 180 */ "2334",
            /* 181 */ "060",
            /* 182 */ "063",
            /* 183 */ "364",
            /* 184 */ "533",
            /* 185 */ "534",
            /* 186 */ "567",
            /* 187 */ "1191",
            /* 188 */ "1210",
            /* 189 */ "1473",
            /* 190 */ "1827",
            /* 191 */ "069",
            /* 192 */ "701",
            /* 193 */ "2531",
            /* 194 */ "514",
            /* 195 */ "prev_dhash",
            /* 196 */ "064",
            /* 197 */ "496",
            /* 198 */ "790",
            /* 199 */ "1046",
            /* 200 */ "1139",
            /* 201 */ "1505",
            /* 202 */ "1521",
            /* 203 */ "1108",
            /* 204 */ "207",
            /* 205 */ "544",
            /* 206 */ "637",
            /* 207 */ "final",
            /* 208 */ "1173",
            /* 209 */ "1293",
            /* 210 */ "1694",
            /* 211 */ "1939",
            /* 212 */ "1951",
            /* 213 */ "1993",
            /* 214 */ "2353",
            /* 215 */ "2515",
            /* 216 */ "504",
            /* 217 */ "601",
            /* 218 */ "857",
            /* 219 */ "modify",
            /* 220 */ "spam_request",
            /* 221 */ "p_121_aa_1101_test4",
            /* 222 */ "866",
            /* 223 */ "1427",
            /* 224 */ "1502",
            /* 225 */ "1638",
            /* 226 */ "1744",
            /* 227 */ "2153",
            /* 228 */ "068",
            /* 229 */ "382",
            /* 230 */ "725",
            /* 231 */ "1704",
            /* 232 */ "1864",
            /* 233 */ "1990",
            /* 234 */ "2003",
            /* 235 */ "Asia/Dubai",
            /* 236 */ "508",
            /* 237 */ "531",
            /* 238 */ "1387",
            /* 239 */ "1474",
            /* 240 */ "1632",
            /* 241 */ "2307",
            /* 242 */ "2386",
            /* 243 */ "819",
            /* 244 */ "2014",
            /* 245 */ "066",
            /* 246 */ "387",
            /* 247 */ "1468",
            /* 248 */ "1706",
            /* 249 */ "2186",
            /* 250 */ "2261",
            /* 251 */ "471",
            /* 252 */ "728",
            /* 253 */ "1147",
            /* 254 */ "1372",
            /* 255 */ "1961",
        ],
    ];
}

// ─── BinaryDecoder ────────────────────────────────────────────────────────────

/// <summary>
/// Decodes WhatsApp binary XML frames into <see cref="BinaryNode"/> trees.
/// Logic ported 1:1 from whatsmeow binary/decoder.go (tulir/whatsmeow).
/// </summary>
public static class BinaryDecoder
{
    /// <summary>
    /// Decode a single WhatsApp binary XML frame.
    /// The caller is responsible for stripping any framing header before calling.
    /// </summary>
    public static BinaryNode Decode(ReadOnlyMemory<byte> data)
    {
        var dec = new Decoder(data);
        return dec.ReadNode() ?? throw new InvalidDataException("Root node is null");
    }

    /// <summary>Decode from a plain byte array.</summary>
    public static BinaryNode Decode(byte[] data) => Decode(data.AsMemory());
}

// ─── Internal decoder state machine ─────────────────────────────────────────

file sealed class Decoder
{
    private readonly ReadOnlyMemory<byte> _data;
    private int _index;

    internal Decoder(ReadOnlyMemory<byte> data)
    {
        _data = data;
        _index = 0;
    }

    // ── primitive readers ─────────────────────────────────────────────────────

    private void CheckEos(int length)
    {
        if (_index + length > _data.Length)
            throw new EndOfStreamException(
                $"Unexpected end of stream: need {length} bytes at offset {_index}, have {_data.Length - _index}");
    }

    private byte ReadByte()
    {
        CheckEos(1);
        return _data.Span[_index++];
    }

    private int ReadIntN(int n, bool littleEndian)
    {
        CheckEos(n);
        var span = _data.Span;
        int ret = 0;
        for (int i = 0; i < n; i++)
        {
            int shift = littleEndian ? i : n - i - 1;
            ret |= span[_index + i] << (shift * 8);
        }
        _index += n;
        return ret;
    }

    private int ReadInt8()  => ReadIntN(1, false);
    private int ReadInt16() => ReadIntN(2, false);
    private int ReadInt32() => ReadIntN(4, false);

    private int ReadInt20()
    {
        CheckEos(3);
        var span = _data.Span;
        int ret = ((span[_index] & 0x0F) << 16)
                | (span[_index + 1] << 8)
                |  span[_index + 2];
        _index += 3;
        return ret;
    }

    // ── packed-string readers (Nibble8 / Hex8) ────────────────────────────────

    private string ReadPacked8(int tag)
    {
        int startByte = ReadByte();
        int count     = startByte & 0x7F;
        bool trimLast = (startByte >> 7) != 0;

        var sb = new StringBuilder(count * 2);
        for (int i = 0; i < count; i++)
        {
            byte curr = ReadByte();
            sb.Append((char)UnpackByte(tag, (byte)((curr & 0xF0) >> 4)));
            sb.Append((char)UnpackByte(tag,  (byte)(curr & 0x0F)));
        }

        string result = sb.ToString();
        return trimLast ? result[..^1] : result;
    }

    private static byte UnpackByte(int tag, byte value) => tag switch
    {
        WaTokens.Nibble8 => UnpackNibble(value),
        WaTokens.Hex8    => UnpackHex(value),
        _                => throw new InvalidDataException($"Unknown packed tag {tag}")
    };

    private static byte UnpackNibble(byte value)
    {
        if (value < 10) return (byte)('0' + value);
        if (value == 10) return (byte)'-';
        if (value == 11) return (byte)'.';
        if (value == 15) return 0;          // null nibble (padding)
        throw new InvalidDataException($"Invalid nibble value {value}");
    }

    private static byte UnpackHex(byte value)
    {
        if (value < 10) return (byte)('0' + value);
        if (value < 16) return (byte)('A' + value - 10);
        throw new InvalidDataException($"Invalid hex nibble value {value}");
    }

    // ── list size ─────────────────────────────────────────────────────────────

    private int ReadListSize(int tag) => tag switch
    {
        WaTokens.ListEmpty => 0,
        WaTokens.List8     => ReadInt8(),
        WaTokens.List16    => ReadInt16(),
        _ => throw new InvalidDataException(
                 $"readListSize: unknown tag {tag} at position {_index}")
    };

    // ── value reader ──────────────────────────────────────────────────────────

    /// <summary>Reads one value from the stream.</summary>
    /// <param name="asString">
    /// When true, binary payloads are decoded as UTF-8 strings.
    /// When false, they are returned as <see cref="byte[]"/>.
    /// </param>
    internal object? Read(bool asString)
    {
        int tag = ReadByte();

        switch (tag)
        {
            case WaTokens.ListEmpty:
                return null;

            case WaTokens.List8:
            case WaTokens.List16:
                return ReadList(tag);

            case WaTokens.Binary8:
            {
                int size = ReadInt8();
                return ReadBytesOrString(size, asString);
            }
            case WaTokens.Binary20:
            {
                int size = ReadInt20();
                return ReadBytesOrString(size, asString);
            }
            case WaTokens.Binary32:
            {
                int size = ReadInt32();
                return ReadBytesOrString(size, asString);
            }

            case WaTokens.Dictionary0:
            case WaTokens.Dictionary1:
            case WaTokens.Dictionary2:
            case WaTokens.Dictionary3:
            {
                int dictIndex  = tag - WaTokens.Dictionary0;
                int tokenIndex = ReadInt8();
                var dict = WaTokens.DoubleByte[dictIndex];
                if (tokenIndex < 0 || tokenIndex >= dict.Length)
                    throw new InvalidDataException(
                        $"Double-byte token index {tokenIndex} out of range for dict {dictIndex}");
                return dict[tokenIndex];
            }

            case WaTokens.JIDPair:    return ReadJIDPair();
            case WaTokens.InteropJID: return ReadInteropJID();
            case WaTokens.FBJID:      return ReadFBJID();
            case WaTokens.ADJID:      return ReadADJID();

            case WaTokens.Nibble8:
            case WaTokens.Hex8:
                return ReadPacked8(tag);

            default:
                // Single-byte token range: 1..235
                if (tag >= 1 && tag < WaTokens.SingleByte.Length)
                    return WaTokens.SingleByte[tag];

                throw new InvalidDataException(
                    $"Unknown token 0x{tag:X2} ({tag}) at position {_index}");
        }
    }

    // ── JID readers ───────────────────────────────────────────────────────────

    private Jid ReadJIDPair()
    {
        var user   = Read(asString: true);
        var server = Read(asString: true) as string
                  ?? throw new InvalidDataException("JIDPair: server is null");
        var userStr = user as string ?? "";
        return new Jid(userStr, server);
    }

    private Jid ReadInteropJID()
    {
        var user       = Read(asString: true) as string ?? "";
        int device     = ReadInt16();
        int integrator = ReadInt16();
        var server     = Read(asString: true) as string ?? "";
        if (server != Jid.ServerInterop)
            throw new InvalidDataException(
                $"InteropJID: expected server '{Jid.ServerInterop}', got '{server}'");
        return new Jid(user, server, (ushort)device, 0, (ushort)integrator);
    }

    private Jid ReadFBJID()
    {
        var user   = Read(asString: true) as string ?? "";
        int device = ReadInt16();
        var server = Read(asString: true) as string ?? "";
        if (server != Jid.ServerMessenger)
            throw new InvalidDataException(
                $"FBJID: expected server '{Jid.ServerMessenger}', got '{server}'");
        return new Jid(user, server, (ushort)device);
    }

    private Jid ReadADJID()
    {
        byte agent  = ReadByte();
        byte device = ReadByte();
        var  user   = Read(asString: true) as string ?? "";
        return new Jid(user, Jid.ServerWhatsApp, device, agent);
    }

    // ── attribute & list readers ──────────────────────────────────────────────

    private Dictionary<string, object?> ReadAttributes(int n)
    {
        if (n == 0) return new Dictionary<string, object?>();

        var attrs = new Dictionary<string, object?>(n);
        for (int i = 0; i < n; i++)
        {
            var keyObj = Read(asString: true);
            if (keyObj is not string key)
                throw new InvalidDataException(
                    $"Attribute key is not a string (type {keyObj?.GetType().Name ?? "null"}) at position {_index}");
            attrs[key] = Read(asString: true);
        }
        return attrs;
    }

    private BinaryNode[] ReadList(int tag)
    {
        int size = ReadListSize(tag);
        var list = new BinaryNode[size];
        for (int i = 0; i < size; i++)
            list[i] = ReadNode()
                   ?? throw new InvalidDataException($"Null node in list at index {i}");
        return list;
    }

    // ── node reader (main entry point) ────────────────────────────────────────

    /// <summary>
    /// Reads a single <see cref="BinaryNode"/> from the stream.
    /// Matches Go's binaryDecoder.readNode() exactly.
    /// </summary>
    internal BinaryNode? ReadNode()
    {
        // 1. Read the list-size tag byte
        int sizeTag  = ReadInt8();
        // 2. Resolve to actual list size (listSize includes tag + attr pairs + optional content)
        int listSize = ReadListSize(sizeTag);

        // 3. Read the node tag/descriptor
        var rawDesc = Read(asString: true);
        string nodeTag = rawDesc as string ?? "";

        if (listSize == 0 || nodeTag == "")
            throw new InvalidDataException(
                $"Invalid node: listSize={listSize}, tag='{nodeTag}' at position {_index}");

        // 4. Read attributes: (listSize - 1) / 2 key-value pairs
        var attrs = ReadAttributes((listSize - 1) >> 1);

        // 5. No content if listSize is odd
        if (listSize % 2 == 1)
            return new BinaryNode { Tag = nodeTag, Attrs = attrs, Content = null };

        // 6. Read content
        var content = Read(asString: false);

        return new BinaryNode { Tag = nodeTag, Attrs = attrs, Content = content };
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private object? ReadBytesOrString(int length, bool asString)
    {
        CheckEos(length);
        var slice = _data.Span.Slice(_index, length);
        _index += length;
        if (asString)
            return Encoding.UTF8.GetString(slice);
        return slice.ToArray();
    }
}
