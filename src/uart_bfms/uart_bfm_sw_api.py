'''
Created on Apr 15, 2021

@author: mballance
'''
import ctypes
import pybfms
from uart_bfms.uart_bfm import UartBfm
import hvlrpc
from numpy.core._internal import ctypes
from typing import List

@hvlrpc.api_exp
class UartBfmSwAPI(object):
    """Implements the Python side of the C API to the BFM"""
    
    def __init__(self, bfms : List[UartBfm] = None):
        if bfms is None:
            self.bfms = []
        else:
            self.bfms = bfms
            
        print("bfms=" + str(bfms) + " " + str(self.bfms))

    @hvlrpc.func
    def uart_bfm_config(self,
            bfm_id   : ctypes.c_uint8,
            baud_div : ctypes.c_uint16,
            data_size : ctypes.c_uint8):
        print("uart_bfm_config: " + str(bfm_id) + " " + str(baud_div) + " " + str(data_size))
        bfm : UartBfm = self.bfms[bfm_id]
        bfm.set_divisor(baud_div)
        pass


    @hvlrpc.func
    def uart_bfm_tx_bytes_incr(self, 
            bfm_id : ctypes.c_uint8,
            sval : ctypes.c_uint8,
            nbytes : ctypes.c_uint8):
        """Initiates transmission of `nbytes` starting at `sval` and incrementing"""
        
        # Raise an objection to support running until we're complete
        pybfms.objection.inst().raise_objection()
        pybfms.fork(self._tx_bytes_incr(bfm_id, sval, nbytes))
        
    @hvlrpc.func
    def uart_bfm_rx_bytes_incr(self, 
            bfm_id : ctypes.c_uint8,
            sval : ctypes.c_uint8,
            nbytes : ctypes.c_uint8):
        """Initiates reception of `nbytes` starting at `sval` and incrementing"""
        
        # Raise an objection to support running until we're complete
        pybfms.objection.inst().raise_objection()
        pybfms.fork(self._rx_bytes_incr(bfm_id, sval, nbytes))
    
    async def _tx_bytes_incr(self, bfm_id, sval, nbytes):
        """Generator task sending in traffic"""
        bfm = self.bfms[bfm_id]
        for i in range(nbytes):
            await bfm.xmit(sval+i)
            
        # Drop the objection once we are done
        pybfms.objection.inst().drop_objection()
            
    async def _rx_bytes_incr(self, bfm_id, sval, nbytes):
        """Receive a series of bytes"""
        
        bfm = self.bfms[bfm_id]
        for i in range(nbytes):
            print("--> await recv")
            await bfm.recv()
            print("<-- await recv")
            
        pybfms.objection.inst().drop_objection()
            
            
        
    
