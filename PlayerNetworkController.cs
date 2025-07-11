using UnityEngine;
using System;
using System.Net;
using System.Net.Sockets;

public class PlayerNetworkController : MonoBehaviour
{
    public int playerId = 1;
    public string serverIP = "127.0.0.1";
    public int serverPort = 4000;

    private UdpClient udpClient;
    private Vector3 lastPosition;

    void Start()
    {
        udpClient = new UdpClient();
        udpClient.Connect(serverIP, serverPort);
        lastPosition = transform.position;
    }

    void Update()
    {
        Vector3 currentPosition = transform.position;
        if (currentPosition != lastPosition)
        {
            Vector3 delta = currentPosition - lastPosition;
            byte[] packet = BuildPacket(delta);
            udpClient.Send(packet, packet.Length);
            lastPosition = currentPosition;
        }
    }

    private byte[] BuildPacket(Vector3 delta)
    {
        byte[] buffer = new byte[30];
        int offset = 0;

        // player_id :: 32-bit signed integer (network order)
        Buffer.BlockCopy(BitConverter.GetBytes(IPAddress.HostToNetworkOrder(playerId)), 0, buffer, offset, 4);
        offset += 4;

        // opcode 1 :: 16-bit (network order)
        short opcode = IPAddress.HostToNetworkOrder((short)1);
        Buffer.BlockCopy(BitConverter.GetBytes(opcode), 0, buffer, offset, 2);
        offset += 2;

        // dx :: float64
        long xBits = BitConverter.DoubleToInt64Bits(delta.x);
        Buffer.BlockCopy(BitConverter.GetBytes(IPAddress.HostToNetworkOrder(xBits)), 0, buffer, offset, 8);
        offset += 8;

        // dy :: float64
        long yBits = BitConverter.DoubleToInt64Bits(delta.y);
        Buffer.BlockCopy(BitConverter.GetBytes(IPAddress.HostToNetworkOrder(yBits)), 0, buffer, offset, 8);
        offset += 8;

        // dz :: float64
        long zBits = BitConverter.DoubleToInt64Bits(delta.z);
        Buffer.BlockCopy(BitConverter.GetBytes(IPAddress.HostToNetworkOrder(zBits)), 0, buffer, offset, 8);
        offset += 8;

        return buffer;
    }

    void OnDestroy()
    {
        if (udpClient != null)
        {
            udpClient.Close();
        }
    }
}
