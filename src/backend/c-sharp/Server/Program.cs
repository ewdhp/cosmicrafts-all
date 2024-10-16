using System;
using System.Collections.Concurrent;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

class Program
{
    private static ConcurrentDictionary<WebSocket, (string UserId, string Room)> clients = new ConcurrentDictionary<WebSocket, (string, string)>();

    public static async Task Main(string[] args)
    {
        Console.WriteLine("Starting server...");

        HttpListener listener = new HttpListener();
        listener.Prefixes.Add("http://localhost:8080/");
        listener.Start();
        Console.WriteLine("Listening on http://localhost:8080/");

        while (true)
        {
            HttpListenerContext context = await listener.GetContextAsync();
            if (context.Request.IsWebSocketRequest)
            {
                ProcessWebSocketRequest(context);
            }
            else
            {
                context.Response.StatusCode = 400;
                context.Response.Close();
            }
        }
    }

    private static async void ProcessWebSocketRequest(HttpListenerContext context)
    {
        WebSocketContext wsContext = await context.AcceptWebSocketAsync(null);
        WebSocket webSocket = wsContext.WebSocket;

        // Assign a unique identifier for the user and default room
        string userId = Guid.NewGuid().ToString();
        string room = "default";
        clients.TryAdd(webSocket, (userId, room));

        byte[] buffer = new byte[1024 * 1024];
        try
        {
            while (webSocket.State == WebSocketState.Open)
            {
                WebSocketReceiveResult result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
                if (result.MessageType == WebSocketMessageType.Close)
                {
                    await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, string.Empty, CancellationToken.None);
                    clients.TryRemove(webSocket, out _);
                }
                else
                {
                    string message = Encoding.UTF8.GetString(buffer, 0, result.Count);

                    // Check if the message is a command to join a room
                    if (message.StartsWith("/join "))
                    {
                        string newRoom = message.Substring(6).Trim();
                        clients[webSocket] = (userId, newRoom);
                        await SendMessageAsync(webSocket, $"You have joined room {newRoom}");
                    }
                    else
                    {
                        string broadcastMessage = $"{clients[webSocket].UserId}: {message}";

                        // Broadcast the message to all clients in the same room
                        foreach (var client in clients)
                        {
                            if (client.Key.State == WebSocketState.Open && client.Value.Room == clients[webSocket].Room)
                            {
                                byte[] broadcastBuffer = Encoding.UTF8.GetBytes(broadcastMessage);
                                await client.Key.SendAsync(new ArraySegment<byte>(broadcastBuffer), WebSocketMessageType.Text, true, CancellationToken.None);
                            }
                        }
                    }
                }
            }
        }
        catch (WebSocketException ex)
        {
            Console.WriteLine($"WebSocket error: {ex.Message}");
            clients.TryRemove(webSocket, out _);
        }
    }

    private static async Task SendMessageAsync(WebSocket webSocket, string message)
    {
        byte[] buffer = Encoding.UTF8.GetBytes(message);
        await webSocket.SendAsync(new ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, CancellationToken.None);
    }
}