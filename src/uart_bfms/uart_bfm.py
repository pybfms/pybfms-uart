'''
Created on Apr 14, 2021

@author: mballance
'''

import pybfms

@pybfms.bfm(
    hdl={
        pybfms.BfmType.SystemVerilog : pybfms.bfm_hdl_path(__file__, "hdl/uart_bfm.v"),
        pybfms.BfmType.Verilog : pybfms.bfm_hdl_path(__file__, "hdl/uart_bfm.v")
        }, has_init=True)
class UartBfm(object):
    
    def __init__(self):
        self.recv_cb = None
        self.tx_busy = pybfms.lock()
        self.tx_ev = pybfms.event()
        pass
    
    def set_divisor(self, div):
        self._set_dl(div)
        
    async def xmit(self, data):
        await self.tx_busy.acquire()
        
        self._xmit_req(data)
        
        await self.tx_ev.wait()
        self.tx_ev.clear()
        
        self.tx_busy.release()
        
    
    @pybfms.export_task(pybfms.uint8_t)
    def _recv(self, data):
        if self.recv_cb is not None:
            self.recv_cb(data)
            
    @pybfms.import_task(pybfms.uint8_t)
    def _xmit_req(self, data):
        pass
            
    @pybfms.export_task()
    def _xmit_ack(self):
        self.tx_ev.set()
            
    @pybfms.import_task(pybfms.uint16_t)
    def _set_dl(self, dl):
        pass

