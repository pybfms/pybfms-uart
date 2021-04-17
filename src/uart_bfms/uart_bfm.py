'''
Created on Apr 14, 2021

@author: mballance
'''

import pybfms

@pybfms.bfm(
    hdl={
        pybfms.BfmType.SystemVerilog : pybfms.bfm_hdl_path(__file__, "share/hdl/uart_bfm.v"),
        pybfms.BfmType.Verilog : pybfms.bfm_hdl_path(__file__, "share/hdl/uart_bfm.v")
        }, has_init=True)
class UartBfm(object):
    
    def __init__(self):
        self.recv_cb = []
        self.tx_busy = pybfms.lock()
        self.tx_ev = pybfms.event()
        pass
    
    def set_divisor(self, div):
        self._set_dl(div)
        
    def add_recv_cb(self, cb):
        self.recv_cb.append(cb)
        
    def del_recv_cb(self, cb):
        self.recv_cb.remove(cb)
        
    async def recv(self) -> int:
        
        ev = pybfms.event()
        def cb(data):
            nonlocal ev
            ev.set(data)
            
        self.add_recv_cb(cb)
        await ev.wait()
        self.del_recv_cb(cb)
        
        return ev.data
        
    async def xmit(self, data):
        await self.tx_busy.acquire()
        
        self._xmit_req(data)
        
        await self.tx_ev.wait()
        self.tx_ev.clear()
        
        self.tx_busy.release()
        
    
    @pybfms.export_task(pybfms.uint8_t)
    def _recv(self, data):
        if len(self.recv_cb) > 0:
            for cb in self.recv_cb.copy():
                cb(data)
            
    @pybfms.import_task(pybfms.uint8_t)
    def _xmit_req(self, data):
        pass
            
    @pybfms.export_task()
    def _xmit_ack(self):
        self.tx_ev.set()
            
    @pybfms.import_task(pybfms.uint16_t)
    def _set_dl(self, dl):
        pass

