//
//  TCPConnection.swift
//  ShapeshifterTesting
//
//  Created by Adelita Schule on 1/8/18.
//

import Foundation
import NetworkExtension

extension NWTCPConnection: TCPConnection {}

public enum TCPConnectionError: Error
{
    case invalidNWEndpoint
    case invalidWispParameters
    case networkConnectionFailed
}

public protocol TCPConnection
{
    /// init(upgradeFor connection: TCPConnection)
    
    /*!
     * @property state
     * @discussion The status of the connection. Use KVO to watch this property to get updates.
     */
    var state: NWTCPConnectionState { get }
    
    
    /*!
     * @property viable
     * @discussion YES if the connection can read and write data, NO otherwise. Use KVO to watch this property.
     */
    var isViable: Bool { get }
    
    
    /*!
     * @property hasBetterPath
     * @discussion YES if the system determines there is a better path the destination can be reached if
     *        the caller creates a new connection using the same endpoint and parameters. This can
     *        be done using the convenience upgrade initializer method.
     *        Use KVO to watch this property to get updates.
     */
    var hasBetterPath: Bool { get }
    
    
    /*!
     * @property endpoint
     * @discussion The destination endpoint with which this connection was created.
     */
    var endpoint: NWEndpoint { get }
    
    
    /*!
     * @property connectedPath
     * @discussion The network path over which the connection was established. The caller can query
     *        additional properties from the NWPath object for more information.
     *
     *         Note that this contains a snapshot of information at the time of connection establishment
     *         for this connection only. As a result, some underlying properties might change in time and
     *         might not reflect the path for other connections that might be established at different times.
     */
    var connectedPath: NWPath? { get }
    
    
    /*!
     * @property localAddress
     * @discussion The IP address endpoint from which the connection was connected.
     */
    var localAddress: NWEndpoint? { get }
    
    
    /*!
     * @property remoteAddress
     * @discussion The IP address endpoint to which the connection was connected.
     */
    var remoteAddress: NWEndpoint? { get }
    
    
    /*!
     * @property txtRecord
     * @discussion When the connection is connected to a Bonjour service endpoint, the TXT record associated
     *         with the Bonjour service is available via this property. Beware that the value comes from
     *         the network. Care must be taken when parsing this potentially malicious value.
     */
    var txtRecord: Data? { get }
    
    
    /*!
     * @property error
     * @discussion The connection-wide error property indicates any fatal error that occurred while
     *         processing the connection or performing data reading or writing.
     */
    var error: Error? { get }
    
    
    /*!
     * @method cancel:
     * @discussion Cancel the connection. This will clean up the resources associated with this object
     *         and transition this object to NWTCPConnectionStateCancelled state.
     */
    func cancel()
    
    
    /*!
     * @method readLength:completionHandler:
     * @discussion Read "length" number of bytes. See readMinimumLength:maximumLength:completionHandler:
     *         for a complete discussion of the callback behavior.
     * @param length The exact number of bytes the application wants to read
     *        for a complete discussion of the callback behavior.
     * @param length The exact number of bytes the caller wants to read
     * @param completion The completion handler to be invoked when there is data to read or an error occurred
     */
    func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Swift.Void)
    
    
    /*!
     * @method readMinimumLength:maximumLength:completionHandler:
     *
     * @discussion Read the requested range of bytes. The completion handler will be invoked when:
     *         - Exactly "length" number of bytes have been read. 'data' will be non-nil.
     *
     *         - Fewer than "length" number of bytes, including 0 bytes, have been read, and the connection's
     *         read side has been closed. 'data' might be nil, depending on whether there was any data to be
     *         read when the connection's read side was closed.
     *
     *         - Some fatal error has occurred, and 'data' will be nil.
     *
     *         To know when to schedule a read again, check for the condition whether an error has occurred.
     *
     *        For better performance, the caller should pick the effective minimum and maximum lengths.
     *        For example, if the caller absolutely needs a specific number of bytes before it can
     *        make any progress, use that value as the minimum. The maximum bytes can be the upperbound
     *        that the caller wants to read. Typically, the minimum length can be the caller
     *        protocol fixed-size header and the maximum length can be the maximum size of the payload or
     *        the size of the current read buffer.
     *
     * @param minimum The minimum number of bytes the caller wants to read
     * @param maximum The maximum number of bytes the caller wants to read
     * @param completion The completion handler to be invoked when there is data to read or an error occurred
     */
    func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Swift.Void)
    
    
    /*!
     * @method write:completionHandler:
     * @discussion Write the given data object content. Callers should wait until the completionHandler is executed
     *        before issuing another write.
     * @param data The data object whose content will be written
     * @param completion The completion handler to be invoked when the data content has been written or an error has occurred.
     *         If the error is nil, the write succeeded and the caller can write more data.
     */
    func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Swift.Void)
    
    
    /*!
     * @method writeClose:
     * @discussion Close this connection's write side such that further write requests won't succeed.
     *         Note that this has the effect of closing the read side of the peer connection.
     *         When the connection's read side and write side are closed, the connection is considered
     *         disconnected and will transition to the appropriate state.
     */
    func writeClose()
}
