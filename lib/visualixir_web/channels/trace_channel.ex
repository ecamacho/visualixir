defmodule VisualixirWeb.TraceChannel do
  use Visualixir.Web, :channel
  alias Visualixir.Tracer
  alias VisualixirWeb.Endpoint
  alias Phoenix.Socket

  def join("trace", %{"node" => node}, socket) do
    node = String.to_atom(node)

    if node != node() do
      Tracer.send_module(node)
    end

    Tracer.start(node)

    {:ok, initial_state(node), socket}
  end

  def handle_in("msg_trace", pid_str, %Socket{topic: "trace"} = socket) do
    pid_str |> pid_from_binary() |> Tracer.msg_trace

    {:noreply, socket}
  end

  def handle_in("stop_msg_trace_all", _msg, %Socket{topic: "trace"} = socket) do
    :erlang.nodes()
    |> Enum.each(&Tracer.stop_msg_trace_all/1)

    {:noreply, socket}
  end

  def handle_in("cleanup", _node, socket), do: {:noreply, socket}

  def announce_spawn(pid_map) do
    Endpoint.broadcast! "trace", "spawn", pid_keys_to_binary(pid_map)
  end

  def announce_exit(pid) do
    Endpoint.broadcast! "trace", "exit", %{pid: pid_to_binary(pid)}
  end

  def announce_name(pid, name) do
    Endpoint.broadcast! "trace", "name", %{pid: pid_to_binary(pid), name: name}
  end

  # a list of links is a list of lists
  # [[pid1, pid2], [pid3, pid4], ...]
  def announce_links(links) do
    Endpoint.broadcast! "trace", "links", %{links: pid_pairs_to_binary(links)}
  end

  def announce_link(link), do: announce_links([link])

  def announce_unlink(link) do
    Endpoint.broadcast! "trace", "unlink", %{link: pid_pair_to_binary(link)}
  end

  def announce_msg(from_pid, to_pid, msg) do
    Endpoint.broadcast! "trace", "msg", %{from_pid: pid_to_binary(from_pid),
                                          to_pid: pid_to_binary(to_pid),
                                          msg: inspect(msg)}
  end


  defp initial_state(node) do
    %{pids: pids, ports: ports, links: links} = state = Tracer.initial_state(node)

    %{state |
      pids: pid_keys_to_binary(pids),
      ports: pid_keys_to_binary(ports),
      links: pid_pairs_to_binary(links)}
  end

  defp pid_keys_to_binary(map) do
    Enum.into(map, %{}, fn {pid, info} -> {pid_to_binary(pid), info} end)
  end

  defp pid_pairs_to_binary(pairs) do
    Enum.map(pairs, &pid_pair_to_binary/1)
  end

  defp pid_pair_to_binary([from, to]) do
    [pid_to_binary(from), pid_to_binary(to)]
  end


  defp pid_to_binary(pid) when is_pid(pid) do
    pid
    |> :erlang.pid_to_list
    |> :erlang.list_to_binary
  end

  defp pid_to_binary(port) when is_port(port) do
    port
    |> :erlang.port_to_list
    |> :erlang.list_to_binary
  end

  def pid_from_binary("<" <> _pidstr = binary) do
    binary
    |> :erlang.binary_to_list
    |> :erlang.list_to_pid
  end

  def pid_from_binary(binary) do
    binary
    |> :erlang.binary_to_list
    |> :erlang.list_to_atom
    |> :erlang.whereis
  end

end