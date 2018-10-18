defmodule LoggerJSON.Plug.MetadataFormatters.ELK do
  @moduledoc """
  Formats connection into Logger metadata:

    * `connection.type` - type of connection (Sent or Chunked);
    * `connection.method` - HTTP request method;
    * `connection.request_path` - HTTP request path;
    * `connection.request_id` - value of `X-Request-ID` response header (see `Plug.RequestId`);
    * `connection.status` - HTTP status code sent to a client;
    * `client.user_agent` - value of `User-Agent` header;
    * `client.ip' - value of `X-Forwarded-For` header if present, otherwise - remote IP of a connected client;
    * `client.api_version' - version of API that was requested by a client;
    * `node.hostname` - system hostname;
    * `node.pid` - Erlang VM process identifier;
    * `phoenix.controller` - Phoenix controller that processed the request;
    * `phoenix.action` - Phoenix action that processed the request;
    * `latency_ms` - time in microseconds taken to process the request.
  """

  @doc false
  def build_metadata(conn, latency, client_version_header) do
    latency_ms = System.convert_time_unit(latency, :native, :microsecond)

    [
      connection: %{
        type: connection_type(conn),
        method: conn.method,
        request_path: conn.request_path,
        status: conn.status
      },
      client: %{
        user_agent: LoggerJSON.Plug.get_header(conn, "user-agent"),
        ip: remote_ip(conn),
        api_version: LoggerJSON.Plug.get_header(conn, client_version_header)
      },
      node: node_metadata(),
      latency_ms: latency_ms
    ] ++ phoenix_metadata(conn)
  end

  defp connection_type(%{state: :set_chunked}), do: "chunked"
  defp connection_type(_), do: "sent"

  defp remote_ip(conn) do
    LoggerJSON.Plug.get_header(conn, "x-forwarded-for") || to_string(:inet_parse.ntoa(conn.remote_ip))
  end

  defp phoenix_metadata(%{private: %{phoenix_controller: controller, phoenix_action: action}}) do
    [phoenix: %{controller: controller, action: action}]
  end

  defp phoenix_metadata(_conn) do
    []
  end

  defp node_metadata do
    {:ok, hostname} = :inet.gethostname()

    vm_pid =
      case Integer.parse(System.get_pid()) do
        {pid, _units} -> pid
        _ -> nil
      end

    %{hostname: to_string(hostname), vm_pid: vm_pid}
  end
end