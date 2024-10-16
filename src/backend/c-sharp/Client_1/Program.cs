using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

class Client1
{
    public static async Task Main(string[] args)
    {
        using (ClientWebSocket webSocket = new ClientWebSocket())
        {
            Uri serverUri = new Uri("ws://localhost:8080/");
            await webSocket.ConnectAsync(serverUri, CancellationToken.None);
            Console.WriteLine("Client1 connected to the server.");

            // Join a room
            string joinRoomMessage = "/join room1";
            byte[] buffer = Encoding.UTF8.GetBytes(joinRoomMessage);
            await webSocket.SendAsync(new ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, CancellationToken.None);

            // Send a message to the server
            string message = "Hello from Client1";
            buffer = Encoding.UTF8.GetBytes(message);
            await webSocket.SendAsync(new ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, CancellationToken.None);

            // Receive messages from the server
            buffer = new byte[1024];
            while (webSocket.State == WebSocketState.Open)
            {
                WebSocketReceiveResult result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
                string serverMessage = Encoding.UTF8.GetString(buffer, 0, result.Count);
                Console.WriteLine("Client1 received: " + serverMessage);
            }
        }
    }
}